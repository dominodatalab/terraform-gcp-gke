locals {
  cluster_endpoint       = google_container_cluster.domino_cluster.endpoint
  cluster_ca_certificate = google_container_cluster.domino_cluster.master_auth.0.cluster_ca_certificate
}

data "google_client_config" "current" {}

provider "kubernetes" {
  load_config_file = false

  host                   = "https://${local.cluster_endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(local.cluster_ca_certificate)
}


resource "kubernetes_cluster_role_binding" "client_admin" {
  metadata {
    name = "client-admin"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "User"
    name      = "client"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "kube-system"
  }
  subject {
    kind      = "Group"
    name      = "system:masters"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "local_file" "kubeconfig" {
  filename        = var.kubeconfig_output_path != "" ? var.kubeconfig_output_path : "${path.cwd}/kubeconfig"
  file_permission = "0644"

  sensitive_content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    cluster_name       = var.cluster
    server             = local.cluster_endpoint
    ca_certificate     = local.cluster_ca_certificate
    client_certificate = google_container_cluster.domino_cluster.master_auth.0.client_certificate
    client_key         = google_container_cluster.domino_cluster.master_auth.0.client_key
  })
}
