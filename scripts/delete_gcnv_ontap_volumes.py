#!/usr/bin/env python3
"""Delete Trident-created ONTAP volumes before destroying a GCNV storage pool."""

from __future__ import annotations

import argparse
import json
import subprocess
import time
from collections.abc import Callable
from typing import Any
from urllib.error import HTTPError
from urllib.parse import parse_qsl, quote, urlencode, urlsplit
from urllib.request import Request, urlopen


class CleanupError(RuntimeError):
    """Raised when GCNV volume cleanup cannot be completed safely."""


class PoolAbsent(CleanupError):
    """Raised when the exact storage-pool ONTAP endpoint no longer exists."""


class TransientRequestError(CleanupError):
    """Raised after a transient ONTAP request exhausts its retry."""


def build_ontap_api_url(project: str, location: str, storage_pool: str) -> str:
    """Return the ONTAP proxy URL scoped to exactly one GCNV storage pool."""
    segments = (project, location, storage_pool)
    if any(not segment for segment in segments):
        raise CleanupError("project, location, and storage pool must all be non-empty")
    escaped_project, escaped_location, escaped_pool = (quote(segment, safe="") for segment in segments)
    return (
        "https://netapp.googleapis.com/v1/"
        f"projects/{escaped_project}/locations/{escaped_location}/storagePools/{escaped_pool}/ontap/api"
    )


def _access_token() -> str:
    try:
        result = subprocess.run(
            ["gcloud", "auth", "application-default", "print-access-token"],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.SubprocessError) as error:
        stderr = getattr(error, "stderr", None)
        detail = stderr.strip() if isinstance(stderr, str) and stderr.strip() else str(error)
        raise CleanupError(f"could not obtain a gcloud access token: {detail}") from error
    token = result.stdout.strip()
    if not token:
        raise CleanupError("gcloud returned an empty access token")
    return token


def _request_json(
    opener: Callable[..., Any],
    token: str,
    method: str,
    url: str,
    *,
    not_found_is_absent: bool = False,
    json_body: dict[str, Any] | None = None,
    sleep: Callable[[float], None] = time.sleep,
    deadline: float | None = None,
    monotonic: Callable[[], float] = time.monotonic,
) -> dict[str, Any]:
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    data = None
    if json_body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(json_body).encode()
    request = Request(
        url,
        data=data,
        method=method,
        headers=headers,
    )
    for attempt in range(2):
        request_timeout = 30.0
        if deadline is not None:
            remaining = deadline - monotonic()
            if remaining <= 0:
                raise TransientRequestError(f"{method} {url} exceeded its deadline")
            request_timeout = min(request_timeout, remaining)
        try:
            with opener(request, timeout=request_timeout) as response:
                raw = response.read()
            break
        except HTTPError as error:
            if error.code == 404:
                if method == "GET" and not_found_is_absent:
                    raise PoolAbsent(f"{method} {url} returned 404") from error
                if method in {"PATCH", "DELETE"}:
                    return {}
            if error.code == 429 or 500 <= error.code < 600:
                if attempt == 0:
                    retry_delay = 1.0
                    if deadline is not None:
                        retry_delay = min(retry_delay, max(0.0, deadline - monotonic()))
                    if retry_delay > 0:
                        sleep(retry_delay)
                    continue
                raise TransientRequestError(f"{method} {url} failed after retry: {error}") from error
            raise CleanupError(f"{method} {url} failed: {error}") from error
        except Exception as error:
            raise CleanupError(f"{method} {url} failed: {error}") from error

    if not raw:
        return {}
    try:
        payload = json.loads(raw)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        raise CleanupError(f"{method} {url} returned invalid JSON") from error
    if not isinstance(payload, dict):
        raise CleanupError(f"{method} {url} returned a non-object JSON response")
    return payload


def _ontap_body(payload: dict[str, Any]) -> dict[str, Any] | None:
    body = payload.get("body")
    if body is None:
        body = payload.get("rawResponse")
    return body if isinstance(body, dict) else None


def _volume_page(payload: dict[str, Any]) -> tuple[list[dict[str, Any]], str | None]:
    body = _ontap_body(payload)
    if not isinstance(body, dict):
        raise CleanupError("ONTAP volume response must contain a body.records array")
    records = body.get("records")
    if not isinstance(records, list) or any(not isinstance(record, dict) for record in records):
        raise CleanupError("ONTAP volume response must contain a body.records array")
    links = body.get("_links")
    if links is None:
        return records, None
    if not isinstance(links, dict):
        raise CleanupError("ONTAP volume response _links must be an object")
    next_link = links.get("next")
    if next_link is None:
        return records, None
    href = next_link.get("href") if isinstance(next_link, dict) else None
    if not isinstance(href, str) or not href:
        raise CleanupError("ONTAP volume response _links.next.href must be a non-empty string")
    return records, href


def _all_volume_records(
    opener: Callable[..., Any],
    token: str,
    api_url: str,
    first_url: str,
    *,
    first_not_found_is_absent: bool = False,
    request_sleep: Callable[[float], None] = time.sleep,
    request_deadline: float | None = None,
    request_monotonic: Callable[[], float] = time.monotonic,
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    next_url: str | None = first_url
    visited: set[str] = set()
    while next_url is not None:
        if next_url in visited:
            raise CleanupError("ONTAP volume pagination contains a cycle")
        visited.add(next_url)
        page_records, next_href = _volume_page(
            _request_json(
                opener,
                token,
                "GET",
                next_url,
                not_found_is_absent=first_not_found_is_absent and next_url == first_url,
                sleep=request_sleep,
                deadline=request_deadline,
                monotonic=request_monotonic,
            )
        )
        records.extend(page_records)
        if next_href is None:
            next_url = None
        else:
            parsed = urlsplit(next_href)
            if (
                parsed.scheme
                or parsed.netloc
                or parsed.path != "/api/storage/volumes"
                or not parsed.query
                or parsed.fragment
            ):
                raise CleanupError("ONTAP volume pagination escaped the exact storage-pool endpoint")
            query = urlencode(
                [
                    ("ontap_fields" if key == "fields" else key, value)
                    for key, value in parse_qsl(parsed.query, keep_blank_values=True)
                ]
            )
            next_url = f"{api_url}{parsed.path.removeprefix('/api')}?{query}"
    return records


def _wait_ontap_job(
    opener: Callable[..., Any],
    token: str,
    api_url: str,
    payload: dict[str, Any],
    *,
    sleep: Callable[[float], None],
    monotonic: Callable[[], float],
    timeout_seconds: float,
    poll_interval_seconds: float,
) -> None:
    body = _ontap_body(payload)
    job = body.get("job") if body is not None else None
    if job is None:
        return
    uuid = job.get("uuid") if isinstance(job, dict) else None
    if not isinstance(uuid, str) or not uuid:
        raise CleanupError("ONTAP job response must contain a non-empty job UUID")

    deadline = monotonic() + timeout_seconds
    job_url = f"{api_url}/cluster/jobs/{quote(uuid, safe='')}"
    while True:
        status = _ontap_body(_request_json(opener, token, "GET", job_url, sleep=sleep))
        state = status.get("state") if status is not None else None
        if state == "success":
            return
        if state == "failure":
            message = (status or {}).get("message") or "unknown error"
            raise CleanupError(f"ONTAP job {uuid} failed: {message}")
        if monotonic() >= deadline:
            raise CleanupError(f"Timed out waiting for ONTAP job {uuid}")
        sleep(poll_interval_seconds)


def _non_root_volumes(records: list[dict[str, Any]]) -> list[tuple[str, str, str | None]]:
    if not records:
        return []

    candidates: list[tuple[str, str, str | None]] = []
    root_count = 0
    for record in records:
        nas = record.get("nas")
        path = nas.get("path") if isinstance(nas, dict) else None
        is_svm_root = record.get("is_svm_root")
        if is_svm_root is not None and not isinstance(is_svm_root, bool):
            raise CleanupError("ONTAP volume is_svm_root must be a boolean when present")
        if not isinstance(path, str) and not isinstance(is_svm_root, bool):
            raise CleanupError("every ONTAP volume must contain nas.path or is_svm_root")
        if is_svm_root is True or path == "/":
            root_count += 1
            continue

        uuid = record.get("uuid")
        if not isinstance(uuid, str) or not uuid:
            raise CleanupError("every non-root volume UUID must be a non-empty string")
        name = record.get("name")
        candidates.append((uuid, name if isinstance(name, str) else uuid, path))
    if root_count != 1:
        raise CleanupError(f"expected exactly one SVM root volume, found {root_count}")
    return candidates


def cleanup(
    project: str,
    location: str,
    storage_pool: str,
    *,
    token: str | None = None,
    opener: Callable[..., Any] = urlopen,
    sleep: Callable[[float], None] = time.sleep,
    monotonic: Callable[[], float] = time.monotonic,
    timeout_seconds: float = 600,
    poll_interval_seconds: float = 5,
) -> None:
    """Delete all non-root ONTAP volumes in exactly one GCNV storage pool."""
    api_url = build_ontap_api_url(project, location, storage_pool)
    access_token = token or _access_token()
    volumes_url = f"{api_url}/storage/volumes"
    list_url = (
        f"{volumes_url}?" f"{urlencode({'ontap_fields': 'uuid,name,nas.path,is_svm_root', 'max_records': 10000})}"
    )
    requested: set[str] = set()

    def request_deletes(
        candidates: list[tuple[str, str, str | None]],
    ) -> tuple[set[str], dict[str, CleanupError]]:
        newly_requested: set[str] = set()
        errors: dict[str, CleanupError] = {}
        for uuid, name, path in candidates:
            if uuid in requested:
                continue
            print(f"Deleting GCNV ONTAP volume {name} ({uuid}) from storage pool {storage_pool}")
            volume_url = f"{volumes_url}/{quote(uuid, safe='')}"
            try:
                if path:
                    _wait_ontap_job(
                        opener,
                        access_token,
                        api_url,
                        _request_json(
                            opener,
                            access_token,
                            "PATCH",
                            volume_url,
                            json_body={"body": {"nas": {"path": ""}}},
                            sleep=sleep,
                        ),
                        sleep=sleep,
                        monotonic=monotonic,
                        timeout_seconds=timeout_seconds,
                        poll_interval_seconds=poll_interval_seconds,
                    )
                _wait_ontap_job(
                    opener,
                    access_token,
                    api_url,
                    _request_json(
                        opener,
                        access_token,
                        "DELETE",
                        f"{volume_url}?{urlencode({'force': 'true'})}",
                        sleep=sleep,
                    ),
                    sleep=sleep,
                    monotonic=monotonic,
                    timeout_seconds=timeout_seconds,
                    poll_interval_seconds=poll_interval_seconds,
                )
            except CleanupError as error:
                errors[uuid] = error
            else:
                requested.add(uuid)
                newly_requested.add(uuid)
        return newly_requested, errors

    def raise_if_stalled(
        candidates: list[tuple[str, str, str | None]],
        newly_requested: set[str],
        errors: dict[str, CleanupError],
    ) -> None:
        in_flight = any(uuid in requested for uuid, _, _ in candidates)
        if errors and not newly_requested and not in_flight:
            if len(errors) == 1:
                raise next(iter(errors.values()))
            detail = "; ".join(f"{uuid}: {error}" for uuid, error in errors.items())
            raise CleanupError(f"could not delete ONTAP volumes: {detail}")

    try:
        candidates = _non_root_volumes(
            _all_volume_records(
                opener,
                access_token,
                api_url,
                list_url,
                first_not_found_is_absent=True,
                request_sleep=sleep,
            )
        )
        newly_requested, errors = request_deletes(candidates)
        raise_if_stalled(candidates, newly_requested, errors)
    except PoolAbsent:
        print(f"GCNV storage pool {storage_pool} is already absent")
        return

    deadline = monotonic() + timeout_seconds
    while candidates:
        try:
            candidates = _non_root_volumes(
                _all_volume_records(
                    opener,
                    access_token,
                    api_url,
                    list_url,
                    first_not_found_is_absent=True,
                    request_sleep=sleep,
                )
            )
        except PoolAbsent:
            print(f"GCNV storage pool {storage_pool} is already absent")
            return
        if not candidates:
            break
        newly_requested, errors = request_deletes(candidates)
        raise_if_stalled(candidates, newly_requested, errors)
        if monotonic() >= deadline:
            names = ", ".join(name for _, name, _ in candidates)
            detail = "; ".join(f"{uuid}: {error}" for uuid, error in errors.items())
            suffix = f"; latest errors: {detail}" if detail else ""
            raise CleanupError(f"Timed out waiting for GCNV ONTAP volumes to be deleted: {names}{suffix}")
        sleep(poll_interval_seconds)

    print(f"GCNV storage pool {storage_pool} has no non-root ONTAP volumes")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--location", required=True)
    parser.add_argument("--storage-pool", required=True)
    args = parser.parse_args()
    cleanup(args.project, args.location, args.storage_pool)


if __name__ == "__main__":
    main()
