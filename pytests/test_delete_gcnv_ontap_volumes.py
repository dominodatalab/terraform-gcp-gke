import json
import subprocess
import sys
from email.message import Message
from pathlib import Path
from unittest import TestCase
from unittest.mock import Mock, patch
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from scripts.delete_gcnv_ontap_volumes import (  # noqa: E402
    CleanupError,
    TransientRequestError,
    _access_token,
    _request_json,
    build_ontap_api_url,
    cleanup,
)


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
    def __init__(self, get_payloads, mutation_payloads=None):
        self.get_payloads = iter(get_payloads)
        self.mutation_payloads = iter(mutation_payloads or [])
        self.requests = []
        self.request_objects = []

    def __call__(self, request, timeout):
        self.requests.append((request.method, request.full_url, timeout))
        self.request_objects.append(request)
        if request.method == "GET":
            payload = next(self.get_payloads)
            if isinstance(payload, Exception):
                raise payload
            return FakeResponse(payload)
        payload = next(self.mutation_payloads, {})
        if isinstance(payload, Exception):
            raise payload
        return FakeResponse(payload)


class TestDeleteGCNVOntapVolumes(TestCase):
    def test_builds_an_exact_pool_qualified_url(self):
        self.assertEqual(
            build_ontap_api_url("project-name", "us-east4-a", "deploy/name"),
            "https://netapp.googleapis.com/v1/projects/project-name/locations/us-east4-a/"
            "storagePools/deploy%2Fname/ontap/api",
        )

    def test_preserves_root_and_deletes_every_non_root_volume(self):
        initial = {
            "body": {
                "records": [
                    {
                        "uuid": "root-uuid",
                        "name": "svm_root",
                        "nas": {"path": "/"},
                        "is_svm_root": True,
                        "state": "online",
                        "type": "rw",
                    },
                    {
                        "uuid": "online-uuid",
                        "name": "trident-online",
                        "nas": {"path": "/trident-online"},
                        "state": "online",
                        "type": "rw",
                    },
                    {
                        "uuid": "offline-uuid",
                        "name": "trident-offline",
                        "nas": {"path": "/trident-offline"},
                        "state": "offline",
                        "type": "dp",
                    },
                ]
            }
        }
        only_root = {"body": {"records": [initial["body"]["records"][0]]}}
        opener = FakeOpener([initial, only_root])

        cleanup(
            "project-name",
            "us-east4-a",
            "deployment",
            token="token",
            opener=opener,
            sleep=lambda _: None,
        )

        prefix = (
            "https://netapp.googleapis.com/v1/projects/project-name/locations/us-east4-a/"
            "storagePools/deployment/ontap/api/storage/volumes"
        )
        self.assertEqual(
            [(method, url) for method, url, _ in opener.requests],
            [
                ("GET", f"{prefix}?ontap_fields=uuid%2Cname%2Cnas.path%2Cis_svm_root&max_records=10000"),
                ("PATCH", f"{prefix}/online-uuid"),
                ("DELETE", f"{prefix}/online-uuid?force=true"),
                ("PATCH", f"{prefix}/offline-uuid"),
                ("DELETE", f"{prefix}/offline-uuid?force=true"),
                ("GET", f"{prefix}?ontap_fields=uuid%2Cname%2Cnas.path%2Cis_svm_root&max_records=10000"),
            ],
        )
        for method, url, _ in opener.requests:
            if method == "GET":
                self.assertIn("ontap_fields=uuid%2Cname%2Cnas.path%2Cis_svm_root", url)
                self.assertIn("max_records=10000", url)
        patch_requests = [request for request in opener.request_objects if request.method == "PATCH"]
        self.assertEqual(
            [json.loads(request.data) for request in patch_requests],
            [{"body": {"nas": {"path": ""}}}, {"body": {"nas": {"path": ""}}}],
        )
        self.assertTrue(all(request.get_header("Content-type") == "application/json" for request in patch_requests))

    def test_malformed_list_response_fails_before_deleting_anything(self):
        opener = FakeOpener([{"body": {}}])

        with self.assertRaisesRegex(CleanupError, "body.records"):
            cleanup(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=lambda _: None,
            )

        self.assertEqual([request[0] for request in opener.requests], ["GET"])

    def test_missing_uuid_fails_before_deleting_anything(self):
        opener = FakeOpener(
            [
                {
                    "body": {
                        "records": [
                            {"uuid": "root-uuid", "nas": {"path": "/"}},
                            {"name": "unsafe", "nas": {"path": "/unsafe"}},
                            {"uuid": "otherwise-valid", "nas": {"path": "/valid"}},
                        ]
                    }
                }
            ]
        )

        with self.assertRaisesRegex(CleanupError, "non-root volume UUID"):
            cleanup(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=lambda _: None,
            )

        self.assertEqual([request[0] for request in opener.requests], ["GET"])

    def test_follows_pagination_before_deleting_anything(self):
        root = {"uuid": "root", "nas": {"path": "/"}}
        opener = FakeOpener(
            [
                {
                    "body": {
                        "records": [root, {"uuid": "one", "nas": {"path": "/one"}}],
                        "_links": {
                            "next": {
                                "href": "/api/storage/volumes?" "fields=uuid,name,nas.path,is_svm_root&start.uuid=two"
                            }
                        },
                    }
                },
                {"body": {"records": [{"uuid": "two", "nas": {"path": "/two"}}]}},
                {"body": {"records": [root]}},
            ]
        )

        cleanup(
            "project-name",
            "us-east4-a",
            "deployment",
            token="token",
            opener=opener,
            sleep=lambda _: None,
        )

        self.assertEqual(
            [request[0] for request in opener.requests],
            ["GET", "GET", "PATCH", "DELETE", "PATCH", "DELETE", "GET"],
        )
        self.assertEqual(
            opener.requests[1][1],
            "https://netapp.googleapis.com/v1/projects/project-name/locations/us-east4-a/"
            "storagePools/deployment/ontap/api/storage/volumes?"
            "ontap_fields=uuid%2Cname%2Cnas.path%2Cis_svm_root&start.uuid=two",
        )

    def test_rejects_escaping_pagination_before_deleting_anything(self):
        opener = FakeOpener(
            [
                {
                    "body": {
                        "records": [{"uuid": "one", "nas": {"path": "/one"}}],
                        "_links": {
                            "next": {
                                "href": "/api/storage/volumes/../../../../storagePools/other/"
                                "ontap/api/storage/volumes?start.uuid=two"
                            }
                        },
                    }
                }
            ]
        )

        with self.assertRaisesRegex(CleanupError, "escaped"):
            cleanup("project-name", "us-east4-a", "deployment", token="token", opener=opener)

        self.assertEqual([request[0] for request in opener.requests], ["GET"])

    def test_rejects_malformed_and_cyclic_pagination(self):
        malformed = FakeOpener([{"body": {"records": [], "_links": {"next": {"href": 123}}}}])
        with self.assertRaisesRegex(CleanupError, "non-empty string"):
            cleanup("project-name", "us-east4-a", "deployment", token="token", opener=malformed)

        cyclic = FakeOpener(
            [
                {
                    "body": {
                        "records": [],
                        "_links": {"next": {"href": "/api/storage/volumes?fields=uuid"}},
                    }
                },
                {
                    "body": {
                        "records": [],
                        "_links": {"next": {"href": "/api/storage/volumes?fields=uuid"}},
                    }
                },
            ]
        )
        with self.assertRaisesRegex(CleanupError, "cycle"):
            cleanup("project-name", "us-east4-a", "deployment", token="token", opener=cyclic)

    def test_missing_junction_path_is_treated_as_non_root(self):
        root = {"uuid": "root", "nas": {"path": "/"}}
        opener = FakeOpener(
            [
                {
                    "body": {
                        "records": [
                            root,
                            {"uuid": "unmounted", "name": "unmounted", "is_svm_root": False},
                        ]
                    }
                },
                {"body": {"records": [root]}},
            ]
        )

        cleanup("project-name", "us-east4-a", "deployment", token="token", opener=opener)

        self.assertIn(
            (
                "DELETE",
                "https://netapp.googleapis.com/v1/projects/project-name/locations/us-east4-a/"
                "storagePools/deployment/ontap/api/storage/volumes/unmounted?force=true",
                30,
            ),
            opener.requests,
        )

    def test_deletes_volume_created_while_cleanup_is_polling(self):
        root = {"uuid": "root", "nas": {"path": "/"}}
        opener = FakeOpener(
            [
                {"body": {"records": [root, {"uuid": "one", "nas": {"path": "/one"}}]}},
                {
                    "body": {
                        "records": [
                            root,
                            {"uuid": "one", "nas": {"path": "/one"}},
                            {"uuid": "two", "nas": {"path": "/two"}},
                        ]
                    }
                },
                {"body": {"records": [root]}},
            ]
        )

        cleanup(
            "project-name",
            "us-east4-a",
            "deployment",
            token="token",
            opener=opener,
            sleep=lambda _: None,
        )

        delete_urls = [url for method, url, _ in opener.requests if method == "DELETE"]
        self.assertEqual(len(delete_urls), 2)
        self.assertTrue(delete_urls[0].endswith("/one?force=true"))
        self.assertTrue(delete_urls[1].endswith("/two?force=true"))

    def test_waits_for_unmount_and_delete_jobs(self):
        root = {"uuid": "root", "nas": {"path": "/"}}
        opener = FakeOpener(
            [
                {"body": {"records": [root, {"uuid": "one", "nas": {"path": "/one"}}]}},
                {"rawResponse": {"state": "running"}},
                {"rawResponse": {"state": "success"}},
                {"rawResponse": {"state": "success"}},
                {"body": {"records": [root]}},
            ],
            mutation_payloads=[
                {"body": {"job": {"uuid": "unmount-job"}}},
                {"body": {"job": {"uuid": "delete-job"}}},
            ],
        )

        cleanup(
            "project-name",
            "us-east4-a",
            "deployment",
            token="token",
            opener=opener,
            sleep=lambda _: None,
        )

        api = (
            "https://netapp.googleapis.com/v1/projects/project-name/locations/us-east4-a/"
            "storagePools/deployment/ontap/api"
        )
        self.assertEqual(
            [(method, url) for method, url, _ in opener.requests],
            [
                ("GET", f"{api}/storage/volumes?ontap_fields=uuid%2Cname%2Cnas.path%2Cis_svm_root&max_records=10000"),
                ("PATCH", f"{api}/storage/volumes/one"),
                ("GET", f"{api}/cluster/jobs/unmount-job"),
                ("GET", f"{api}/cluster/jobs/unmount-job"),
                ("DELETE", f"{api}/storage/volumes/one?force=true"),
                ("GET", f"{api}/cluster/jobs/delete-job"),
                ("GET", f"{api}/storage/volumes?ontap_fields=uuid%2Cname%2Cnas.path%2Cis_svm_root&max_records=10000"),
            ],
        )

    def test_concurrent_volume_deletion_during_unmount_is_idempotent(self):
        url = "https://netapp.googleapis.com/"
        root = {"uuid": "root", "nas": {"path": "/"}}
        opener = FakeOpener(
            [
                {"body": {"records": [root, {"uuid": "one", "nas": {"path": "/one"}}]}},
                {"body": {"records": [root]}},
            ],
            mutation_payloads=[
                HTTPError(url, 404, "Not Found", Message(), None),
                HTTPError(url, 404, "Not Found", Message(), None),
            ],
        )

        cleanup(
            "project-name",
            "us-east4-a",
            "deployment",
            token="token",
            opener=opener,
            sleep=lambda _: None,
        )

        self.assertEqual(
            [method for method, _, _ in opener.requests],
            ["GET", "PATCH", "DELETE", "GET"],
        )

    def test_job_failure_stops_before_delete(self):
        root = {"uuid": "root", "nas": {"path": "/"}}
        opener = FakeOpener(
            [
                {"body": {"records": [root, {"uuid": "one", "nas": {"path": "/one"}}]}},
                {"rawResponse": {"state": "failure", "message": "unmount blocked"}},
            ],
            mutation_payloads=[{"body": {"job": {"uuid": "unmount-job"}}}],
        )

        with self.assertRaisesRegex(CleanupError, "unmount blocked"):
            cleanup(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=lambda _: None,
            )

        self.assertNotIn("DELETE", [method for method, _, _ in opener.requests])

    def test_job_timeout_stops_before_delete(self):
        root = {"uuid": "root", "nas": {"path": "/"}}
        opener = FakeOpener(
            [
                {"body": {"records": [root, {"uuid": "one", "nas": {"path": "/one"}}]}},
                {"rawResponse": {"state": "running"}},
            ],
            mutation_payloads=[{"body": {"job": {"uuid": "unmount-job"}}}],
        )

        with self.assertRaisesRegex(CleanupError, "Timed out"):
            cleanup(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=lambda _: None,
                monotonic=iter([0.0, 2.0]).__next__,
                timeout_seconds=1.0,
            )

        self.assertNotIn("DELETE", [method for method, _, _ in opener.requests])

    def test_retries_parent_after_deleting_its_clone(self):
        url = "https://netapp.googleapis.com/"
        root = {"uuid": "root", "nas": {"path": "/"}}
        opener = FakeOpener(
            [
                {
                    "rawResponse": {
                        "records": [
                            root,
                            {"uuid": "parent", "nas": {"path": "/parent"}},
                            {"uuid": "clone", "nas": {"path": "/clone"}},
                        ]
                    }
                },
                {"body": {"records": [root, {"uuid": "parent", "is_svm_root": False}]}},
                {"body": {"records": [root]}},
            ],
            mutation_payloads=[
                {},
                HTTPError(url, 409, "volume has a clone", Message(), None),
                {},
                {},
                {},
            ],
        )

        cleanup(
            "project-name",
            "us-east4-a",
            "deployment",
            token="token",
            opener=opener,
            sleep=lambda _: None,
        )

        delete_urls = [url for method, url, _ in opener.requests if method == "DELETE"]
        prefix = (
            "https://netapp.googleapis.com/v1/projects/project-name/locations/us-east4-a/"
            "storagePools/deployment/ontap/api/storage/volumes"
        )
        self.assertEqual(
            delete_urls,
            [
                f"{prefix}/parent?force=true",
                f"{prefix}/clone?force=true",
                f"{prefix}/parent?force=true",
            ],
        )

    def test_already_absent_pool_is_success(self):
        url = "https://netapp.googleapis.com/"
        opener = FakeOpener([HTTPError(url, 404, "Not Found", Message(), None)])

        cleanup("project-name", "us-east4-a", "deployment", token="token", opener=opener)

        self.assertEqual([request[0] for request in opener.requests], ["GET"])

    def test_second_page_404_fails_instead_of_claiming_pool_is_absent(self):
        url = "https://netapp.googleapis.com/"
        opener = FakeOpener(
            [
                {
                    "body": {
                        "records": [],
                        "_links": {"next": {"href": "/api/storage/volumes?start.uuid=two"}},
                    }
                },
                HTTPError(url, 404, "Not Found", Message(), None),
            ]
        )

        with self.assertRaisesRegex(CleanupError, "failed"):
            cleanup("project-name", "us-east4-a", "deployment", token="token", opener=opener)

    def test_missing_root_classification_fails_before_deleting(self):
        opener = FakeOpener([{"body": {"records": [{"uuid": "unknown"}]}}])

        with self.assertRaisesRegex(CleanupError, "nas.path or is_svm_root"):
            cleanup("project-name", "us-east4-a", "deployment", token="token", opener=opener)

        self.assertEqual([request[0] for request in opener.requests], ["GET"])

    def test_non_boolean_root_flag_fails_before_deleting(self):
        opener = FakeOpener([{"body": {"records": [{"uuid": "root", "is_svm_root": "true"}]}}])

        with self.assertRaisesRegex(CleanupError, "must be a boolean"):
            cleanup("project-name", "us-east4-a", "deployment", token="token", opener=opener)

        self.assertEqual([request[0] for request in opener.requests], ["GET"])

    def test_missing_or_duplicate_root_fails_before_deleting(self):
        no_root = FakeOpener([{"body": {"records": [{"uuid": "data", "nas": {"path": "/data"}}]}}])
        with self.assertRaisesRegex(CleanupError, "exactly one SVM root"):
            cleanup("project-name", "us-east4-a", "deployment", token="token", opener=no_root)
        self.assertEqual([request[0] for request in no_root.requests], ["GET"])

        duplicate_root = FakeOpener(
            [
                {
                    "body": {
                        "records": [
                            {"uuid": "root-one", "nas": {"path": "/"}},
                            {"uuid": "root-two", "is_svm_root": True},
                        ]
                    }
                }
            ]
        )
        with self.assertRaisesRegex(CleanupError, "found 2"):
            cleanup(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=duplicate_root,
            )
        self.assertEqual([request[0] for request in duplicate_root.requests], ["GET"])

    def test_empty_volume_inventory_is_already_clean(self):
        opener = FakeOpener([{"body": {"records": []}}])

        cleanup("project-name", "us-east4-a", "deployment", token="token", opener=opener)

        self.assertEqual([request[0] for request in opener.requests], ["GET"])

    def test_delete_404_is_idempotent_and_non_404_http_error_fails(self):
        url = "https://netapp.googleapis.com/"

        def not_found(*_, **__):
            raise HTTPError(url, 404, "Not Found", Message(), None)

        def forbidden(*_, **__):
            raise HTTPError(url, 403, "Forbidden", Message(), None)

        self.assertEqual(_request_json(not_found, "token", "DELETE", url), {})
        with self.assertRaisesRegex(CleanupError, "403"):
            _request_json(forbidden, "token", "DELETE", url)

    def test_retries_one_transient_request(self):
        url = "https://netapp.googleapis.com/"
        opener = FakeOpener(
            [
                HTTPError(url, 503, "Unavailable", Message(), None),
                {"body": {"records": []}},
            ]
        )
        sleeps: list[float] = []

        self.assertEqual(
            _request_json(opener, "token", "GET", url, sleep=sleeps.append),
            {"body": {"records": []}},
        )
        self.assertEqual(len(opener.requests), 2)
        self.assertEqual(sleeps, [1])

    def test_exhausted_transient_request_raises(self):
        url = "https://netapp.googleapis.com/"
        opener = FakeOpener(
            [
                HTTPError(url, 503, "Unavailable", Message(), None),
                HTTPError(url, 503, "Unavailable", Message(), None),
            ]
        )

        with self.assertRaisesRegex(TransientRequestError, "503"):
            _request_json(opener, "token", "GET", url, sleep=lambda _: None)

        self.assertEqual(len(opener.requests), 2)

    @patch(
        "scripts.delete_gcnv_ontap_volumes.subprocess.run",
        side_effect=subprocess.CalledProcessError(1, ["gcloud"], stderr="permission denied"),
    )
    def test_access_token_error_includes_stderr(self, _run):
        with self.assertRaisesRegex(CleanupError, "permission denied"):
            _access_token()

    @patch(
        "scripts.delete_gcnv_ontap_volumes.subprocess.run",
        return_value=Mock(stdout="token\n"),
    )
    def test_access_token_uses_application_default_credentials(self, run):
        self.assertEqual(_access_token(), "token")
        run.assert_called_once_with(
            ["gcloud", "auth", "application-default", "print-access-token"],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )

    def test_times_out_if_a_deleted_volume_remains(self):
        volume_response = {
            "body": {
                "records": [
                    {"uuid": "root-uuid", "nas": {"path": "/"}},
                    {"uuid": "stuck-uuid", "nas": {"path": "/stuck"}},
                ]
            }
        }
        opener = FakeOpener([volume_response, volume_response])

        with self.assertRaisesRegex(CleanupError, "Timed out"):
            cleanup(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=lambda _: None,
                monotonic=iter([0.0, 2.0]).__next__,
                timeout_seconds=1.0,
            )

    def test_timeout_includes_latest_delete_errors(self):
        url = "https://netapp.googleapis.com/"
        volume_response = {
            "body": {
                "records": [
                    {"uuid": "root-uuid", "name": "root", "nas": {"path": "/"}},
                    {"uuid": "in-flight", "name": "stuck-a", "nas": {"path": ""}},
                    {"uuid": "delete-error", "name": "stuck-b", "nas": {"path": ""}},
                ]
            }
        }
        conflict = HTTPError(url, 409, "volume has a clone", Message(), None)
        opener = FakeOpener(
            [volume_response, volume_response],
            mutation_payloads=[{}, conflict, conflict],
        )

        with self.assertRaisesRegex(
            CleanupError,
            "Timed out.*stuck-a, stuck-b.*delete-error:.*409",
        ):
            cleanup(
                "project-name",
                "us-east4-a",
                "deployment",
                token="token",
                opener=opener,
                sleep=lambda _: None,
                monotonic=iter([0.0, 2.0]).__next__,
                timeout_seconds=1.0,
            )
