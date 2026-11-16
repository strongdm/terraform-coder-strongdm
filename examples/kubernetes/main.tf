terraform {
  required_version = ">= 1.5"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "2.20.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
  }
}

provider "coder" {}

provider "kubernetes" {}

variable "namespace" {
  description = "Kubernetes namespace for workspaces. The Coder provisioner needs permission to manage Deployments and PersistentVolumeClaims in it."
  type        = string
  default     = "coder"
}

variable "image" {
  description = "Workspace image. It needs curl, unzip, sha256sum, sed and awk; see the Dockerfile."
  type        = string
  default     = "codercom/example-base:ubuntu"
}

variable "home_disk_size" {
  description = "Size of the persistent home volume."
  type        = string
  default     = "10Gi"
}

variable "strongdm_client_id" {
  description = "Client ID of the StrongDM Coder integration (Settings > Integrations > Coder)."
  type        = string
}

variable "strongdm_provider_id" {
  description = "ID of the StrongDM external auth provider on the Coder server (CODER_EXTERNAL_AUTH_<n>_ID)."
  type        = string
  default     = "strongdm"
}

variable "strongdm_app_domain" {
  description = "StrongDM control plane host, for example app.uk.strongdm.com for the UK region."
  type        = string
  default     = "app.strongdm.com"
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

locals {
  name = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  labels = {
    "app.kubernetes.io/name"     = "coder-workspace"
    "app.kubernetes.io/instance" = local.name
    "com.coder.workspace.id"     = data.coder_workspace.me.id
  }
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
}

module "strongdm" {
  count          = data.coder_workspace.me.start_count
  source         = "git::https://github.com/strongdm/terraform-coder-strongdm//strongdm?ref=v0.2.0"
  agent_id       = coder_agent.main.id
  client_id      = var.strongdm_client_id
  provider_id    = var.strongdm_provider_id
  sdm_app_domain = var.strongdm_app_domain
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "${local.name}-home"
    namespace = var.namespace
    labels    = local.labels
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.home_disk_size
      }
    }
  }
}

resource "kubernetes_deployment_v1" "workspace" {
  count            = data.coder_workspace.me.start_count
  wait_for_rollout = false
  metadata {
    name      = local.name
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    replicas = 1
    strategy {
      type = "Recreate"
    }
    selector {
      match_labels = local.labels
    }
    template {
      metadata {
        labels = local.labels
      }
      spec {
        security_context {
          run_as_user = 1000
        }
        init_container {
          name              = "home-permissions"
          image             = var.image
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c", "chown 1000:1000 /home/coder && chmod 755 /home/coder"]
          security_context {
            run_as_user = 0
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
          }
        }
        container {
          name              = "workspace"
          image             = var.image
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c", coder_agent.main.init_script]
          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }
          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
          }
        }
        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
          }
        }
      }
    }
  }
}
