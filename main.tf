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

resource "kubernetes_cluster_role" "traefik-ingress-controller" {
    metadata {
        name = "traefik-ingress-controller"
    }

    rule {
        api_groups = [""]
        resources  = ["services", "endpoints", "secrets"]
        verbs      = ["get", "list", "watch"]
    }

    rule {
        api_groups = ["extensions"]
        resources  = ["ingresses"]
        verbs      = ["get", "list", "watch"]
    }

    rule {
        api_groups = ["extensions"]
        resources  = ["ingresses/status"]
        verbs      = ["update"]
    }
}

resource "kubernetes_cluster_role_binding" "traefik-ingress-controller" {
    metadata {
        name = "traefik-ingress-controller"
    }
    role_ref {
        api_group = "rbac.authorization.k8s.io"
        kind = "ClusterRole"
        name = "traefik-ingress-controller"
    }
    subject {
        kind = "ServiceAccount"
        namespace = "traefik"
        name = "traefik-ingress-controller"
    }
}

resource "kubernetes_service_account" "traefik-ingress-controller" {
  metadata {
    name = "traefik-ingress-controller"
    namespace = "traefik"
  }
  automount_service_account_token = true
}

resource "kubernetes_daemonset" "traefik-ingress-controller" {
  metadata {
    name = "traefik"
    namespace = "traefik"
    labels = {
      app = "traefik-ingress-controller"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "traefik-ingress-controller"
      }
    }


    template {
      metadata {
        labels = {
          app = "traefik-ingress-controller"
        }
      }

      spec {
        container {
          image = "traefik:v1.7.12"
          name  = "traefik"
          port {
            name = "http"
            container_port = 80
            host_port = 80
          }
          port {
            name = "https"
            container_port = 443
            host_port = 443
          }
          security_context {
             capabilities {
               drop = ["ALL"]
               add = ["NET_BIND_SERVICE"]
             }
          }
          args = [
            "--api",
            "--kubernetes",
            "--logLevel=INFO",
            "--defaultentrypoints=http,https",
            "--entrypoints=Name:https Address::443 TLS",
            "--entrypoints=Name:http Address::80"
          ]

        }
        service_account_name = "traefik-ingress-controller"
        host_network = true
      }
    }
  }
}
