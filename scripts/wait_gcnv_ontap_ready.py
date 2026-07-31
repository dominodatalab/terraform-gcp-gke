#!/usr/bin/env python3
"""Wait for the SVM root volume in a GCNV ONTAP-mode storage pool."""

from __future__ import annotations

import argparse
import sys
import time
from collections.abc import Callable
from pathlib import Path
from typing import Any
from urllib.parse import urlencode
from urllib.request import urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts.delete_gcnv_ontap_volumes import (  # noqa: E402
    CleanupError,
    PoolAbsent,
    TransientRequestError,
    _access_token,
    _all_volume_records,
    build_ontap_api_url,
)


def _matching_root_volumes(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    roots = []
    for record in records:
        name = record.get("name")
        nas = record.get("nas")
        path = nas.get("path") if isinstance(nas, dict) else None
        state = record.get("state")
        volume_type = record.get("type")
        if not isinstance(name, str):
            raise CleanupError("every ONTAP volume must contain a string name")
        if not isinstance(path, str):
            raise CleanupError(f"ONTAP volume {name} must contain a string nas.path")
        if not isinstance(state, str):
            raise CleanupError(f"ONTAP volume {name} must contain a string state")
        if not isinstance(volume_type, str):
            raise CleanupError(f"ONTAP volume {name} must contain a string type")
        if name.lower().endswith("_root") and path == "/" and state.lower() == "online" and volume_type.lower() == "rw":
            roots.append(record)
    return roots


def wait_until_ready(
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
    """Wait until exactly one online read-write SVM root volume exists."""
    api_url = build_ontap_api_url(project, location, storage_pool)
    access_token = token or _access_token()
    query = urlencode(
        {
            "ontap_fields": "name,nas.path,is_svm_root,state,type",
            "max_records": 10000,
        }
    )
    list_url = f"{api_url}/storage/volumes?{query}"
    deadline = monotonic() + timeout_seconds
    last_status = "found 0 matching root volumes"

    while True:
        if monotonic() >= deadline:
            raise CleanupError(f"Timed out waiting for GCNV ONTAP readiness: {last_status}")
        try:
            roots = _matching_root_volumes(
                _all_volume_records(
                    opener,
                    access_token,
                    api_url,
                    list_url,
                    first_not_found_is_absent=True,
                    request_sleep=sleep,
                    request_deadline=deadline,
                    request_monotonic=monotonic,
                )
            )
            if len(roots) == 1:
                print(f"GCNV storage pool {storage_pool} ONTAP root volume is ready")
                return
            if len(roots) > 1:
                raise CleanupError(f"found {len(roots)} matching root volumes in GCNV storage pool {storage_pool}")
            last_status = "found 0 matching root volumes"
        except (PoolAbsent, TransientRequestError) as error:
            last_status = str(error)

        remaining = deadline - monotonic()
        if remaining <= 0:
            raise CleanupError(f"Timed out waiting for GCNV ONTAP readiness: {last_status}")
        sleep(min(poll_interval_seconds, remaining))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", required=True)
    parser.add_argument("--location", required=True)
    parser.add_argument("--storage-pool", required=True)
    args = parser.parse_args()
    wait_until_ready(args.project, args.location, args.storage_pool)


if __name__ == "__main__":
    main()
