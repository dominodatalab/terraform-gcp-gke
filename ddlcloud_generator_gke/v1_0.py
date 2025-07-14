from copy import deepcopy
from typing import Self

from domino_tf_base_schemas import (
    BaseTFConfig,
    BaseTFOutput,
    TFSet,
    ValidatingBaseModel,
)
from packaging.version import Version
from pydantic import model_validator


class GKEGeneratorException(Exception):
    pass


class GKEOutputs(BaseTFOutput):
    _version: str = "0.1.0"
    google_filestore_ip_address: str = "${module.gke_cluster.google_filestore_instance.ip_address}"
    google_filestore_file_share: str = "/${module.gke_cluster.google_filestore_instance.file_share}"
    google_external_dns: str = "${module.gke_cluster.dns}"
    google_bucket_name: str = "${module.gke_cluster.bucket_name}"
    google_project: str = "${module.gke_cluster.project}"
    google_platform_service_account: str = "${module.gke_cluster.service_accounts.platform.account_id}"
    google_cluster_uuid: str = "${module.gke_cluster.uuid}"
    google_gcr_service_account: str = "${module.gke_cluster.service_accounts.gcr.email}"
    google_artifact_registry: str = (
        "${module.gke_cluster.domino_artifact_repository.location}-docker.pkg.dev/${module.gke_cluster.domino_artifact_repository.project}/${module.gke_cluster.domino_artifact_repository.repository_id}"
    )
    nfs_instance_ip: str = "${module.gke_cluster.nfs_instance.ip_address}"
    nfs_instance_path: str = "${module.gke_cluster.nfs_instance.nfs_path}"


class GKENamespaces(ValidatingBaseModel):
    platform: str = "domino-platform"
    compute: str = "domino-compute"


class GKEStorage(ValidatingBaseModel):
    class Store(ValidatingBaseModel):
        enabled: bool
        capacity: int

    class GCSSettings(ValidatingBaseModel):
        force_destroy_on_deletion: bool = False

    filestore: Store = Store(enabled=True, capacity=1024)
    nfs_instance: Store = Store(enabled=False, capacity=100)
    gcs: GCSSettings = GCSSettings()

    @model_validator(mode="after")
    def validate_stores(self) -> Self:
        if self.filestore.enabled and self.nfs_instance.enabled:
            raise ValueError("Cannot enable both filestore and nfs instance")
        return self


class GKEManagedDNS(ValidatingBaseModel):
    enabled: bool = False
    name: str | None = None
    dns_name: str | None = None
    service_prefixes: list[str] | None = None


class GKEKMS(ValidatingBaseModel):
    database_encryption_key_name: str | None = None


class GKESettings(ValidatingBaseModel):
    class PublicAccess(ValidatingBaseModel):
        enabled: bool = False
        cidrs: list[str] | None = None

    class Kubeconfig(ValidatingBaseModel):
        path: str | None = None

    k8s_version: str | None = None
    release_channel: str | None = None
    public_access: PublicAccess = PublicAccess()
    control_plane_ports: list[str] | None = None
    advanced_datapath: bool | None = None
    network_policies: bool | None = None
    vertical_pod_autoscaling: bool | None = None
    kubeconfig: Kubeconfig = Kubeconfig()


class GKENodePool(ValidatingBaseModel):
    min_count: int | None = None
    max_count: int | None = None
    initial_count: int | None = None
    max_pods: int | None = None
    preemptible: bool | None = None
    disk_size_gb: int | None = None
    image_type: str | None = None
    instance_type: str | None = None
    gpu_accelerator: str | None = None
    labels: dict[str, str] | None = None
    taints: list[str] | None = None
    node_locations: list[str] | None = None


class GKENodePools(ValidatingBaseModel):
    compute: GKENodePool = GKENodePool()
    platform: GKENodePool = GKENodePool()
    gpu: GKENodePool = GKENodePool()


class GKEModule(ValidatingBaseModel):
    source: str
    project: str | None = None
    migration_permissions: bool | None = None
    tags: dict[str, str] | None = None
    location: str
    deploy_id: str
    namespaces: GKENamespaces = GKENamespaces()
    allowed_ssh_ranges: list[str] | None = None
    storage: GKEStorage = GKEStorage()
    managed_dns: GKEManagedDNS = GKEManagedDNS()
    kms: GKEKMS = GKEKMS()
    gke: GKESettings = GKESettings()
    node_pools: GKENodePools = GKENodePools()
    additional_node_pools: dict[str, GKENodePool] | None = None


class GKEModules(ValidatingBaseModel):
    gke_cluster: GKEModule


class GKEConfig(BaseTFConfig):
    name: str = "gke_cluster"
    module: GKEModules
    output: GKEOutputs = GKEOutputs()


class GKEGenerator:
    version = "1.0"
    module_id = "gke"

    @classmethod
    def load_tfset(cls, configs: dict) -> TFSet:
        _configs = deepcopy(configs)
        main = _configs["configs"].pop("main")
        if isinstance(main, dict):
            main = GKEConfig(**main)
        _configs.pop("module_id", None)
        _configs.pop("version", None)
        if _configs != {"configs": {}}:
            raise GKEGeneratorException(f"Config has extra values: {_configs}")
        return TFSet(
            configs={"main": main},
            module_id=cls.module_id,
            version=cls.version,
        )

    @classmethod
    def upgrade(cls, existing_config: dict) -> TFSet:
        if existing_config["module_id"] != cls.module_id:
            raise GKEGeneratorException(
                f"Cannot upgrade from {existing_config['module_id']} module type using {cls.module_id} module"
            )
        if len(existing_config["configs"]) != 1:
            raise GKEGeneratorException(f"Can't upgrade GKE config, exactly one config expected: {existing_config}")

        # Upgrades go here
        # if Version(existing_config["version"]) == Version("0.9"):
        #     <parameter changes>
        #     existing_config["verison"] = "1.0"

        if Version(existing_config["version"]) != Version(cls.version):
            raise GKEGeneratorException(f"Attemping to load config with invalid version: {existing_config['version']}")

        return cls.load_tfset(existing_config)

    @classmethod
    def subparser(cls, subparser, parents):
        gke_subparser = subparser.add_parser("gke", help="GKE Terraform Generator", parents=parents)
        gke_subparser.add_argument("--location", help="GCP Location (ie region/zone)", default="us-west1-b")
        gke_subparser.add_argument("--kubernetes-version", help="Kubernetes Version", default="1.21")
        gke_subparser.add_argument("--module-version", help="Version of terraform-gcp-gke module", default="v3.1.3")
        gke_subparser.add_argument(
            "--kubeconfig_path", help="Override path for generated kubeconfig", default="kubeconfig"
        )
        gke_subparser.add_argument("--dev", help="Development defaults", action="store_true")
        gke_subparser.set_defaults(generator=cls.generate_gke_module)
        return gke_subparser

    @classmethod
    def generate_gke_module(cls, args, existing_config: dict | None) -> TFSet:
        """Creates the data required to configure the terraform-gcp-gke Terraform module."""

        if existing_config:
            return cls.upgrade(existing_config)

        return cls.load_tfset(
            {
                "configs": {
                    "main": GKEConfig(
                        module=GKEModules(
                            gke_cluster=GKEModule(
                                source=f"github.com/dominodatalab/terraform-gcp-gke?ref={args.module_version}",
                                deploy_id=args.deploy_id,
                                location=args.location,
                                gke=GKESettings(kubeconfig=GKESettings.Kubeconfig(path=args.kubeconfig_path)),
                            )
                        ),
                    )
                }
            }
        )
