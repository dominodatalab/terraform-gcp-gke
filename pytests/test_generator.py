from copy import deepcopy
from unittest import TestCase

import yaml

from ddlcloud_generator_gke import (
    GKEGenerator,
    GKEGeneratorException,
    GKENodePool,
    GKEStorage,
)

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
                    "--kubeconfig-path",
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

        with self.subTest("upgrade"):
            args = parse_args(["gke", "--deploy-id", "test"])
            self.assertEqual(tf_module.configs["main"].module.gke_cluster.location, "some-location")
            upgrade_tf_module = GKEGenerator.generate_gke_module(args, tf_module.model_dump(by_alias=True))
            self.assertEqual(tf_module, upgrade_tf_module)
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
        gke_cluster.storage.filestore.enabled = False
        gke_cluster.storage.nfs_instance.enabled = True
        gke_cluster.storage.gcs.force_destroy_on_deletion = True
        gke_cluster.managed_dns.enabled = True
        gke_cluster.managed_dns.name = "some-zone-name"
        gke_cluster.managed_dns.dns_name = "some-dns-name"
        gke_cluster.managed_dns.service_prefixes = ["app-", "test-"]
        gke_cluster.kms.database_encryption_key_name = "some-key-name"
        gke_cluster.gke.k8s_version = "3"  # exactly pi
        gke_cluster.gke.release_channel = "SHAKEY"
        gke_cluster.gke.public_access.enabled = True
        gke_cluster.gke.public_access.cidrs = ["9.10.11.12/13", "14.15.16.17/18"]
        gke_cluster.gke.control_plane_ports = ["443", "8443"]
        gke_cluster.gke.advanced_datapath = False
        gke_cluster.gke.network_policies = True
        gke_cluster.gke.vertical_pod_autoscaling = False
        gke_cluster.gke.kubeconfig.path = "/tmp/kubeconfig/path"
        gke_cluster.node_pools.platform.initial_count = 2
        gke_cluster.node_pools.compute.initial_count = 2
        gke_cluster.node_pools.gpu.initial_count = 2
        gke_cluster.additional_node_pools = {
            "extra_pool": GKENodePool(
                min_count=0,
                max_count=10,
                initial_count=5,
                max_pods=15,
                preemptible=True,
                disk_size_gb=100,
                image_type="some-image-type",
                instance_type="some-instance-type",
                gpu_accelerator="some-gpu-type",
                labels={"some-label": "some-value"},
                taints=["some.com/taint=taint-value"],
                node_locations=["some-locaiton"],
            )
        }

        for module in tf_module.configs.values():
            validate(module)

    def test_store_multi_enable(self):
        values = {
            "filestore": {"enabled": True, "capacity": 1024},
            "nfs_instance": {"enabled": True, "capacity": 100},
        }
        with self.assertRaisesRegex(ValueError, "Cannot enable both filestore and nfs instance"):
            GKEStorage(**values)

        values["filestore"]["enabled"] = False
        GKEStorage(**values)

        values["filestore"]["enabled"] = False
        values["nfs_instance"]["enabled"] = True
        GKEStorage(**values)

    def test_upgrade(self):
        with open("fixtures/defaults.yaml") as f:
            existing_config = yaml.safe_load(f)

        with self.subTest("Load existing config"):
            new_tf_module = self.get_tfmodule()
            loaded_tf_module = GKEGenerator.upgrade(deepcopy(existing_config))

            # for vals in loaded_tf_module.configs.values():
            #    self.assertEqual(type(vals), GKEConfig)
            self.assertEqual(loaded_tf_module, new_tf_module)

        with self.subTest("Load incorrect module"):
            _existing_config = deepcopy(existing_config)
            _existing_config["module_id"] = "eks"
            with self.assertRaisesRegex(GKEGeneratorException, "Cannot upgrade from eks module type using gke module"):
                GKEGenerator.upgrade(_existing_config)

        with self.subTest("Non-one amount of configs"):
            _existing_config = deepcopy(existing_config)
            _existing_config["configs"]["extra_config"] = {}
            with self.assertRaisesRegex(
                GKEGeneratorException, "Can't upgrade GKE config, exactly one config expected.*extra_config"
            ):
                GKEGenerator.upgrade(_existing_config)
            _existing_config["configs"].pop("extra_config")
            _existing_config["configs"].pop("main")
            with self.assertRaisesRegex(
                GKEGeneratorException, "Can't upgrade GKE config, exactly one config expected: {'configs': {}"
            ):
                GKEGenerator.upgrade(_existing_config)

        with self.subTest("Load unknown gke module version"):
            _existing_config = deepcopy(existing_config)
            _existing_config["version"] = "6.6.6"
            with self.assertRaisesRegex(GKEGeneratorException, "Attemping to load config with invalid version: 6.6.6"):
                GKEGenerator.upgrade(_existing_config)

    def test_load_tfset(self):
        with open("fixtures/defaults.yaml") as f:
            existing_config = yaml.safe_load(f)

        existing_config["module_id"] = "eks"
        existing_config["version"] = "6.6.6"

        loaded_tf_module = GKEGenerator.load_tfset(existing_config)
        self.assertNotEqual(loaded_tf_module.module_id, "eks")
        self.assertNotEqual(loaded_tf_module.version, "6.6.6")

        with self.subTest("Error on existing_values"):
            existing_config["configs"]["extra_config"] = {}
            with self.assertRaisesRegex(GKEGeneratorException, "Config has extra values"):
                GKEGenerator.load_tfset(existing_config)
