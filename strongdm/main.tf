terraform {
  required_version = ">= 1.9"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.5"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
  }
}

variable "agent_id" {
  description = "The ID of a Coder agent."
  type        = string
}

variable "client_id" {
  description = "Client ID of the StrongDM Coder integration. Not a secret."
  type        = string

  validation {
    condition     = trimspace(var.client_id) != ""
    error_message = "client_id is required."
  }
}

variable "sdm_version" {
  description = "StrongDM CLI version to install. Signing in through Coder needs 56.36.0 or later."
  type        = string
  default     = "56.36.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.sdm_version))
    error_message = "sdm_version must be a release number such as 56.36.0."
  }
}

variable "arch" {
  description = "CPU architecture of the workspace: amd64 or arm64."
  type        = string
  default     = "amd64"

  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "arch must be amd64 or arm64."
  }
}

variable "sdm_app_domain" {
  description = "StrongDM control plane."
  type        = string
  default     = "app.strongdm.com"
}

variable "home" {
  description = "Home directory of the workspace user."
  type        = string
  default     = "/home/coder"
}

variable "connect_all" {
  description = "Connect every resource the workspace owner can use once the listener is up."
  type        = bool
  default     = true
}

# The zip's URL and checksum for this version, from StrongDM's release endpoint.
data "http" "sdm_cli" {
  url = "https://${var.sdm_app_domain}/release?software=sdm-cli&os=linux&arch=${var.arch}&version=${var.sdm_version}"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && can(jsondecode(self.response_body).sha256)
      error_message = "StrongDM has no Linux ${var.arch} CLI release ${var.sdm_version}."
    }
  }
}

data "coder_workspace" "me" {}

locals {
  sdm_cli = jsondecode(data.http.sdm_cli.response_body)

  # Settings for the scripts, and for sdm in every terminal.
  env = {
    SDM_CLI_URL          = local.sdm_cli.url
    SDM_CLI_SHA256       = lower(local.sdm_cli.sha256)
    SDM_APP_DOMAIN       = var.sdm_app_domain
    SDM_HOME             = "${var.home}/.sdm"
    SDM_CREDENTIAL_FILE  = "${var.home}/.config/strongdm/coder-source.json"
    STRONGDM_CLIENT_ID   = var.client_id
    STRONGDM_CONNECT_ALL = tostring(var.connect_all)
    STRONGDM_LOG_DIR     = "${var.home}/.coder-modules/strongdm/strongdm/logs"
    CODER_AGENT_URL      = data.coder_workspace.me.access_url
  }
}

resource "coder_env" "strongdm" {
  for_each = local.env

  agent_id = var.agent_id
  name     = each.key
  value    = each.value
}

resource "coder_script" "install" {
  agent_id           = var.agent_id
  display_name       = "StrongDM CLI"
  icon               = "/icon/database.svg"
  run_on_start       = true
  start_blocks_login = true
  script             = file("${path.module}/scripts/install-sdm.sh")
}

resource "coder_script" "listen" {
  agent_id     = var.agent_id
  display_name = "StrongDM listener"
  icon         = "/icon/database.svg"
  run_on_start = true
  script       = file("${path.module}/scripts/sdm-listen.sh")
}
