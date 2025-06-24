from unittest import TestCase

import yaml

from ddlcloud_generator_gke import GKEStorage

from .generate import parse_args, validate


class TestGenerator(TestCase):
    maxDiff = None

    def get_tfmodule(self, input_args: list | None = None):
        input_args = input_args or []
        args = parse_args(["gke", "--deploy-id", "test", *input_args])
        return args.generator(args, {})

    def test_generate_gke_module(self):
        with open("fixtures/defaults.yaml") as f:
            defaults = yaml.safe_load(f)

        with self.subTest("defaults"):
            tf_module = self.get_tfmodule()
            self.assertDictEqual(tf_module.model_dump(by_alias=True), defaults)
            self.assertEqual(len(tf_module.configs), 1)
            for module in tf_module.configs.values():
                validate(module)

        with self.subTest("overrides"):
            tf_module = self.get_tfmodule(
                [
                    "--location",
                    "some-location",
                    "--module-version",
                    "some-module-version",
                    "--kubeconfig_path",
                    "/path/to/kubeconfig",
                    "--dev",
                ]
            )
            gke_cluster = defaults["configs"]["main"]["module"]["gke_cluster"]
            gke_cluster["gke"]["kubeconfig"]["path"] = "/path/to/kubeconfig"
            gke_cluster["location"] = "some-location"
            gke_cluster["source"] = "github.com/dominodatalab/terraform-gcp-gke?ref=some-module-version"
            self.assertDictEqual(tf_module.model_dump(by_alias=True), defaults)
            for module in tf_module.configs.values():
                validate(module)

    def test_module_settings(self):
        tf_module = self.get_tfmodule()
        gke_cluster = tf_module.configs["main"].module.gke_cluster
        gke_cluster.project = "test-gcp-project"
        gke_cluster.migration_permissions = True
        gke_cluster.tags = {"some-tag-name": "some-tag-value"}
        gke_cluster.location = "some-location"
        gke_cluster.namespaces.platform = "test-platform"
        gke_cluster.namespaces.compute = "test-compute"
        gke_cluster.allowed_ssh_ranges = ["1.2.3.4/32", "5.6.7.8/24"]
        gke_cluster.storage = GKEStorage()
        gke_cluster.storage.filestore.enabled = False
        gke_cluster.storage.nfs_instance.enabled = True
        gke_cluster.storage.gcs.force_destroy_on_deletion = True

        for module in tf_module.configs.values():
            validate(module)
