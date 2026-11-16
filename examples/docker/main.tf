terraform {
  required_version = ">= 1.5"
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "2.20.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.2"
    }
  }
}

provider "coder" {}

provider "docker" {}

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

resource "docker_image" "workspace" {
  name = "coder-strongdm-workspace:${substr(filesha256("${path.module}/Dockerfile"), 0, 12)}"
  build {
    context    = path.module
    dockerfile = "Dockerfile"
  }
  keep_locally = true
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace.me.id}-home"
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  lifecycle {
    ignore_changes = all
  }
}

resource "docker_container" "workspace" {
  count      = data.coder_workspace.me.start_count
  name       = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  image      = docker_image.workspace.image_id
  hostname   = data.coder_workspace.me.name
  entrypoint = ["sh", "-c", coder_agent.main.init_script]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]

  volumes {
    container_path = "/home/coder"
    volume_name    = docker_volume.home.name
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
}
