terraform {
  backend "s3" {}
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_kubernetes_cluster" "k8s-cluster" {
  name    = var.cluster_name
  region  = var.cluster_region
  version = var.cluster_version

  node_pool {
    name       = "${var.cluster_name}-worker-pool"
    size       = var.cluster_worker_size
    node_count = var.cluster_worker_count
  }
}

provider "kubernetes" {
  host = "${digitalocean_kubernetes_cluster.k8s-cluster.endpoint}"

  client_certificate     = "${base64decode(digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.client_certificate)}"
  client_key             = "${base64decode(digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.cluster_ca_certificate)}"
}

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name      = "tiller"
  }
  role_ref {
    name      = "cluster-admin"
    kind      = "ClusterRole"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "tiller"
    namespace = "kube-system"
    api_group = ""
  }
}

provider "helm" {
  service_account = "tiller"
  kubernetes {
    host = "${digitalocean_kubernetes_cluster.k8s-cluster.endpoint}"

    client_certificate     = "${base64decode(digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(digitalocean_kubernetes_cluster.k8s-cluster.kube_config.0.cluster_ca_certificate)}"
  }
}

#https://www.digitalocean.com/community/questions/hi-after-some-update-of-the-kubernetes-ltd-access-to-a-container-through-hostport-was-broken-i-assume-this-is-related-to-cilium-anyone-known-how-to-fix-that
resource "helm_release" "nginx-ingress" {
  name = "nginx-ingress"
  namespace = "nginx-ingress"
  chart = "stable/nginx-ingress"

  set {
    name = "controller.kind"
    value = "DaemonSet"
  }

  set {
    name = "controller.daemonset.useHostPort"
    value = "true"
  }

  set {
    name = "controller.service.type"
    value = "ClusterIP"
  }

  set {
    name = "controller.hostNetwork"
    value = "true"
  }

}

resource "helm_release" "cert-manager" {
  name = "cert-manager"
  namespace = "kube-system"
  chart = "stable/cert-manager"
  version = "v0.5.2"
}
