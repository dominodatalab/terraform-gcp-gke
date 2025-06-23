from ddlcloud_tf_base_schemas import BaseTFConfig, BaseTFOutput, TFSet
from pydantic import BaseModel

VERSION = "1.0"
MODULE_ID = "gke"


class GKEGeneratorException(Exception):
    pass


class GKEOutputs(BaseTFOutput):
    google_filestore_ip_address: str
    google_filestore_file_share: str
    google_external_dns: str
    google_bucket_name: str
    google_project: str
    google_platform_service_account: str
    google_cluster_uuid: str
    google_gcr_service_account: str
    google_artifact_registry: str
    nfs_instance_ip: str
    nfs_instance_path: str


class GKENamespaces(BaseModel):
    platform: str = "domino-platform"
    compute: str = "domino-compute"


class GKEStorage(BaseModel):
    class Store(BaseModel):
        enabled: bool
        capacity: int

    class GCSSettings(BaseModel):
        force_destroy_on_deletion: bool = False

    # TODO: Validate we don't do both?
    filestore: Store = Store(enabled=True, capacity=1024)
    nfs_instance: Store = Store(enabled=False, capacity=100)
    gcs: GCSSettings = GCSSettings()


class GKEManagedDNS(BaseModel):
    enabled: bool = False
    name: str | None = None
    dns_name: str | None = None
    service_prefixes: list[str] | None = None


class GKEKMS(BaseModel):
    database_encryption_key_name: str | None = None


class GKESettings(BaseModel):
    class PublicAccess(BaseModel):
        enabled: bool = False
        cidrs: list[str] | None = None

    class Kubeconfig(BaseModel):
        path: str | None = None

    k8s_version: str | None = None
    release_channel: str | None = None
    public_access: PublicAccess | None = None
    control_plane_ports: list[str] | None = None
    advanced_datapath: bool | None = None
    network_policies: bool | None = None
    vertical_pod_autoscaling: bool | None = None
    kubeconfig: Kubeconfig | None = None


class GKENodePool(BaseModel):
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


class GKENodePools(BaseModel):
    compute: GKENodePool | None = None
    platform: GKENodePool | None = None
    gpu: GKENodePool | None = None


# TODO: Is it simpler to have the full objects for everything, or leave none for module defaults?
# Also impacts the building of the objects on the infra manifest side
class GKEModule(BaseModel):
    source: str
    project: str | None = None
    migration_permissions: bool | None = None
    tags: dict[str, str] | None = None
    location: str
    deploy_id: str
    namespaces: GKENamespaces = GKENamespaces()
    allowed_ssh_ranges: list[str] | None = None
    storage: GKEStorage | None = None
    managed_dns: GKEManagedDNS | None = None
    kms: GKEKMS | None = None
    gke: GKESettings
    node_pools: GKENodePools | None = None
    additional_node_pools: dict[str, GKENodePool] | None = None


class GKEModules(BaseModel):
    gke_cluster: GKEModule


class GKEConfig(BaseTFConfig):
    name: str = "gke_cluster"
    module: GKEModules
    output: GKEOutputs


def upgrade(existing_config: dict) -> TFSet:
    if len(existing_config["configs"]) != 1:
        print(len(existing_config["configs"]))
        raise GKEGeneratorException("Can't upgrade GKE config, multiple tf modules when one expected!")

    the_cfg = existing_config["configs"]["main"]
    return TFSet(configs={"main": GKEConfig(**the_cfg)}, version=VERSION)


def gke_subparser(subparser, parents):
    gke_subparser = subparser.add_parser("gke", help="GKE Terraform Generator", parents=parents)
    gke_subparser.add_argument("--location", help="GCP Location (ie region/zone)", default="us-west1-b")
    gke_subparser.add_argument("--kubernetes-version", help="Kubernetes Version", default="1.21")
    gke_subparser.add_argument("--module-version", help="Version of terraform-gcp-gke module", default="v3.1.3")
    gke_subparser.add_argument("--kubeconfig_path", help="Override path for generated kubeconfig", default="kubeconfig")
    gke_subparser.add_argument("--dev", help="Development defaults", action="store_true")
    gke_subparser.set_defaults(generator=generate_gke_module)
    return gke_subparser


def generate_gke_module(args, existing_config: dict | None) -> TFSet:
    """Creates the data required to configure the terraform-gcp-gke Terraform module."""

    if existing_config:
        return upgrade(existing_config)

    return TFSet(
        configs={
            "main": GKEConfig(
                module=GKEModules(
                    gke_cluster=GKEModule(
                        source=f"github.com/dominodatalab/terraform-gcp-gke?ref={args.module_version}",
                        deploy_id=args.deploy_id,
                        location=args.location,
                        gke=GKESettings(kubeconfig=GKESettings.Kubeconfig(path=args.kubeconfig_path)),
                    )
                ),
                output=GKEOutputs(
                    google_filestore_ip_address="${module.gke_cluster.google_filestore_instance.ip_address}",
                    google_filestore_file_share="/${module.gke_cluster.google_filestore_instance.file_share}",
                    google_external_dns="${module.gke_cluster.dns}",
                    google_bucket_name="${module.gke_cluster.bucket_name}",
                    google_project="${module.gke_cluster.project}",
                    google_platform_service_account="${module.gke_cluster.service_accounts.platform.account_id}",
                    google_cluster_uuid="${module.gke_cluster.uuid}",
                    google_gcr_service_account="${module.gke_cluster.service_accounts.gcr.email}",
                    google_artifact_registry="${module.gke_cluster.domino_artifact_repository.location}-docker.pkg.dev/${module.gke_cluster.domino_artifact_repository.project}/${module.gke_cluster.domino_artifact_repository.repository_id}",
                    nfs_instance_ip="${module.gke_cluster.nfs_instance.ip_address}",
                    nfs_instance_path="${module.gke_cluster.nfs_instance.nfs_path}",
                ),
            )
        },
        module_id=MODULE_ID,
        version=VERSION,
    )
