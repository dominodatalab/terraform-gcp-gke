from pathlib import Path
from unittest import TestCase

import hcl2

ROOT = Path(__file__).resolve().parents[1]


def load_hcl(name):
    with (ROOT / name).open() as source:
        return hcl2.load(source)


def named_block(config, block_type, resource_type, name):
    for block in config[block_type]:
        if resource_type in block and name in block[resource_type]:
            return block[resource_type][name]
    raise AssertionError(f"Missing {block_type} {resource_type}.{name}")


def resource(config, resource_type, name):
    return named_block(config, "resource", resource_type, name)


def block(config, block_type, name):
    for item in config[block_type]:
        if name in item:
            return item[name]
    raise AssertionError(f"Missing {block_type} {name}")


class TestModuleContract(TestCase):
    def test_gcnv_range_is_automatically_allocated(self):
        address = resource(
            load_hcl("network.tf"),
            '"google_compute_global_address"',
            '"gcnv"',
        )

        self.assertNotIn("address", address)
        self.assertEqual(address["prefix_length"], 24)

    def test_regional_gcnv_uses_the_first_declared_zone(self):
        main = load_hcl("main.tf")
        gcnv = load_hcl("gcnv.tf")
        zones = named_block(gcnv, "data", '"google_compute_zones"', '"gcnv"')

        self.assertEqual(
            zones["count"],
            "${local.gcnv_zone_lookup ? 1 : 0}",
        )
        self.assertEqual(zones["project"], "${var.project}")
        self.assertEqual(zones["region"], "${local.region}")
        self.assertNotIn("status", zones)
        self.assertEqual(
            main["locals"][0]["zone"],
            '${local.is_regional ? format("%s-a", var.location) : var.location}',
        )
        self.assertEqual(
            gcnv["locals"][0]["gcnv_zone_lookup"],
            "${var.storage.gcnv.enabled && !local.gcnv_regional && local.is_regional}",
        )
        self.assertEqual(
            gcnv["locals"][0]["gcnv_location"],
            "${local.gcnv_zone_lookup ? sort(data.google_compute_zones.gcnv[0].names)[0] : "
            "(local.gcnv_regional ? local.region : local.zone)}",
        )

    def test_zonal_gcnv_defaults_domino_node_pools_to_its_zone(self):
        node_pool = resource(
            load_hcl("node_pools.tf"),
            '"google_container_node_pool"',
            '"node_pools"',
        )

        self.assertEqual(
            node_pool["node_locations"],
            "${length(each.value.node_locations) != 0 ? each.value.node_locations : "
            '(var.storage.gcnv.enabled && !local.gcnv_regional && contains(["compute", "platform"], each.key) '
            "? [local.gcnv_location] : google_container_cluster.domino_cluster.node_locations)}",
        )

    def test_terraform_version_supports_terraform_data(self):
        terraform = load_hcl("versions.tf")["terraform"][0]
        self.assertEqual(terraform["required_version"], '">= 1.4"')

    def test_gcnv_workload_identity_uses_configured_namespace(self):
        binding = resource(
            load_hcl("service-accounts.tf"),
            '"google_service_account_iam_binding"',
            '"gcnv"',
        )
        self.assertEqual(
            binding["members"],
            ['"serviceAccount:${var.project}.svc.id.goog[${var.storage.gcnv.trident_namespace}/trident-controller]"'],
        )

    def test_gcnv_service_account_uses_supported_roles(self):
        custom_role = resource(
            load_hcl("service-accounts.tf"),
            '"google_project_iam_custom_role"',
            '"gcnv"',
        )
        self.assertEqual(
            custom_role["permissions"],
            [
                '"netapp.ontap.get"',
                '"netapp.ontap.post"',
                '"netapp.ontap.patch"',
                '"netapp.ontap.delete"',
            ],
        )
        viewer = resource(
            load_hcl("service-accounts.tf"),
            '"google_project_iam_member"',
            '"gcnv_viewer"',
        )
        self.assertEqual(viewer["role"], '"roles/netapp.viewer"')
        self.assertEqual(
            viewer["member"],
            '"serviceAccount:${google_service_account.gcnv[0].email}"',
        )

    def test_gcnv_owns_ontap_provider_and_root_export_rule(self):
        required_providers = load_hcl("versions.tf")["terraform"][0]["required_providers"][0]
        self.assertEqual(
            required_providers["netapp-ontap"],
            {
                "source": '"NetApp/netapp-ontap"',
                "version": '"2.7.0"',
            },
        )

        provider = block(load_hcl("versions.tf"), "provider", '"netapp-ontap"')
        self.assertEqual(
            provider["connection_profiles"][0]["name"],
            "${var.deploy_id}",
        )
        self.assertEqual(
            provider["connection_profiles"][0]["google_netapp_unified_pool"],
            {
                "project_id": "${var.project}",
                "location": "${local.gcnv_location}",
                "storage_pool": "${var.deploy_id}",
            },
        )

        gcnv = load_hcl("gcnv.tf")
        readiness = resource(gcnv, '"terraform_data"', '"gcnv_ontap_ready"')
        self.assertEqual(readiness["count"], "${var.storage.gcnv.enabled ? 1 : 0}")
        self.assertEqual(
            readiness["input"],
            {
                "project": "${var.project}",
                "location": "${google_netapp_storage_pool.gcnv[0].location}",
                "storage_pool": "${google_netapp_storage_pool.gcnv[0].name}",
                "script": '"${path.module}/scripts/wait_gcnv_ontap_ready.py"',
            },
        )
        provisioner = readiness["provisioner"][0]['"local-exec"']
        self.assertIn('python3 "$GCNV_READINESS_SCRIPT"', provisioner["command"])

        volumes = named_block(gcnv, "data", '"netapp-ontap_volumes"', '"gcnv"')
        self.assertEqual(volumes["count"], "${var.storage.gcnv.enabled ? 1 : 0}")
        self.assertEqual(volumes["cx_profile_name"], "${var.deploy_id}")
        self.assertEqual(
            volumes["depends_on"],
            ["${terraform_data.gcnv_ontap_ready}"],
        )
        self.assertEqual(
            gcnv["locals"][0]["gcnv_root_volume"],
            '${var.storage.gcnv.enabled ? one([for volume in '
            'data.netapp-ontap_volumes.gcnv[0].storage_volumes : volume '
            'if endswith(lower(volume.name), "_root") '
            '&& volume.nas.junction_path == "/" '
            '&& lower(volume.state) == "online" '
            '&& lower(volume.type) == "rw"]) : null}',
        )

        export_rule = resource(gcnv, '"netapp-ontap_nfs_export_policy_rule"', '"gcnv_node_access"')
        self.assertEqual(export_rule["count"], "${var.storage.gcnv.enabled ? 1 : 0}")
        self.assertEqual(export_rule["svm_name"], "${local.gcnv_root_volume.svm_name}")
        self.assertEqual(
            export_rule["export_policy_name"],
            "${local.gcnv_root_volume.nas.export_policy_name}",
        )

        output = block(load_hcl("outputs.tf"), "output", '"gcnv"')["value"]
        self.assertEqual(
            output["root_volume_name"],
            "${var.storage.gcnv.enabled ? local.gcnv_root_volume.name : null}",
        )
        self.assertEqual(
            output["export_policy_name"],
            "${var.storage.gcnv.enabled ? local.gcnv_root_volume.nas.export_policy_name : null}",
        )
