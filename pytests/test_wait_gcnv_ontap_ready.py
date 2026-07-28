import json
import sys
from email.message import Message
from pathlib import Path
from unittest import TestCase
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts.delete_gcnv_ontap_volumes import CleanupError  # noqa: E402
from scripts.wait_gcnv_ontap_ready import wait_until_ready  # noqa: E402


class FakeResponse:
    def __init__(self, payload):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return None

    def read(self):
        return json.dumps(self.payload).encode()


class FakeOpener:
    def __init__(self, payloads):
        self.payloads = iter(payloads)
        self.requests = []

    def __call__(self, request, timeout):
        self.requests.append((request.method, request.full_url, timeout))
        payload = next(self.payloads)
        if isinstance(payload, Exception):
            raise payload
        return FakeResponse(payload)


class Clock:
    def __init__(self):
        self.value = 0.0
        self.sleeps = []

    def monotonic(self):
        return self.value

    def sleep(self, seconds):
        self.sleeps.append(seconds)
        self.value += seconds


def volume(name="svm_root", path="/", state="online", volume_type="rw"):
    return {
        "name": name,
        "nas": {"path": path},
        "is_svm_root": path == "/",
        "state": state,
        "type": volume_type,
    }


def inventory(*records):
    return {"body": {"records": list(records)}}


class TestWaitGCNVOntapReady(TestCase):
    def test_returns_when_the_single_root_is_ready(self):
        opener = FakeOpener([inventory(volume())])

        wait_until_ready(
            "project-name",
            "us-east4-a",
            "deployment",
            token="token",
            opener=opener,
            sleep=lambda _: None,
        )

        self.assertEqual(
            opener.requests,
            [
                (
                    "GET",
                    "https://netapp.googleapis.com/v1/projects/project-name/locations/us-east4-a/"
                    "storagePools/deployment/ontap/api/storage/volumes?"
                    "ontap_fields=name%2Cnas.path%2Cis_svm_root%2Cstate%2Ctype&max_records=10000",
                    30,
                )
            ],
        )

    def test_polls_until_the_root_is_ready(self):
        clock = Clock()
        opener = FakeOpener([inventory(), inventory(volume())])

        wait_until_ready(
            "project-name",
            "us-east4-a",
            "deployment",
            token="token",
            opener=opener,
            sleep=clock.sleep,
            monotonic=clock.monotonic,
        )

        self.assertEqual(len(opener.requests), 2)
        self.assertEqual(clock.sleeps, [5])

    def test_retries_absent_pool_and_exhausted_transient_request(self):
        url = "https://netapp.googleapis.com/"
        clock = Clock()
        opener = FakeOpener(
            [
                HTTPError(url, 404, "Not Found", Message(), None),
                HTTPError(url, 503, "Unavailable", Message(), None),
                HTTPError(url, 503, "Unavailable", Message(), None),
                inventory(volume()),
            ]
        )

        wait_until_ready(
            "project-name",
            "us-east4-a",
            "deployment",
            token="token",
            opener=opener,
            sleep=clock.sleep,
            monotonic=clock.monotonic,
        )

        self.assertEqual(len(opener.requests), 4)
        self.assertEqual(clock.sleeps, [5, 1, 5])

    def test_timeout_reports_the_last_observed_root_count(self):
        clock = Clock()
        opener = FakeOpener([inventory()])

        with self.assertRaisesRegex(CleanupError, "Timed out.*found 0 matching root volumes"):
            wait_until_ready(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=clock.sleep,
                monotonic=clock.monotonic,
                timeout_seconds=5,
            )

        self.assertEqual(len(opener.requests), 1)

    def test_clamps_requests_and_sleeps_to_the_deadline(self):
        clock = Clock()
        opener = FakeOpener([inventory()])

        with self.assertRaisesRegex(CleanupError, "Timed out"):
            wait_until_ready(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=clock.sleep,
                monotonic=clock.monotonic,
                timeout_seconds=2,
            )

        self.assertEqual([timeout for _, _, timeout in opener.requests], [2])
        self.assertEqual(clock.sleeps, [2])

    def test_clamps_transient_retry_sleep_to_the_deadline(self):
        clock = Clock()
        url = "https://netapp.googleapis.com/"

        class NearDeadlineOpener:
            requests = []

            def __call__(self, request, timeout):
                self.requests.append((request.method, request.full_url, timeout))
                clock.value += 1.75
                raise HTTPError(url, 503, "Unavailable", Message(), None)

        opener = NearDeadlineOpener()
        with self.assertRaisesRegex(CleanupError, "Timed out"):
            wait_until_ready(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=clock.sleep,
                monotonic=clock.monotonic,
                timeout_seconds=2,
            )

        self.assertEqual([timeout for _, _, timeout in opener.requests], [2])
        self.assertEqual(clock.sleeps, [0.25])

    def test_duplicate_roots_fail_immediately(self):
        opener = FakeOpener([inventory(volume("one_root"), volume("two_root"))])

        with self.assertRaisesRegex(CleanupError, "found 2 matching root volumes"):
            wait_until_ready(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=lambda _: None,
            )

        self.assertEqual(len(opener.requests), 1)

    def test_malformed_inventory_fails_immediately(self):
        opener = FakeOpener([inventory({"name": "svm_root", "nas": {"path": "/"}})])

        with self.assertRaisesRegex(CleanupError, "state"):
            wait_until_ready(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=lambda _: None,
            )

        self.assertEqual(len(opener.requests), 1)
