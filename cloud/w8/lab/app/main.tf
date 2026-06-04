locals {
  app_labels = {
    app = var.app_name
  }
}

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.namespace

    labels = {
      managed-by = "terraform"
    }
  }
}

resource "kubernetes_deployment_v1" "app" {
  wait_for_rollout = true

  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels    = local.app_labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = local.app_labels
    }

    template {
      metadata {
        labels = local.app_labels
      }

      spec {
        security_context {
          run_as_non_root = true

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = var.app_name
          image             = var.container_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = var.container_port
            protocol       = "TCP"
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }

            requests = {
              cpu    = "25m"
              memory = "32Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "http"
            }

            initial_delay_seconds = 10
            period_seconds        = 30
            timeout_seconds       = 2
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "http"
            }

            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 2
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
            run_as_user                = 101

            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace_v1.app.metadata[0].name
    labels    = local.app_labels
  }

  spec {
    type     = "NodePort"
    selector = local.app_labels

    port {
      name        = "http"
      port        = var.service_port
      protocol    = "TCP"
      target_port = "http"
      node_port   = var.node_port
    }
  }
}

