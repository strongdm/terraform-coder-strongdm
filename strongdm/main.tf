terraform {
  required_version = ">= 1.9"

  required_providers {
    coder = {
      source  = "coder/coder"
      version = ">= 2.5"
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

# Pinned until StrongDM's current release reaches 56.36.0, then "latest".
variable "sdm_version" {
  description = "StrongDM CLI version to install, or \"latest\" for StrongDM's current release. Signing in through Coder needs 56.36.0 or later."
  type        = string
  default     = "56.36.0"

  validation {
    condition     = var.sdm_version == "latest" || can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.sdm_version))
    error_message = "sdm_version must be \"latest\" or a release number such as 56.36.0."
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

data "coder_workspace" "me" {}

locals {
  # Settings for the scripts, and for sdm in every terminal.
  env = {
    STRONGDM_CLI_VERSION = var.sdm_version
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
  display_name       = "Install StrongDM CLI"
  icon               = "/icon/database.svg"
  run_on_start       = true
  start_blocks_login = true
  script             = file("${path.module}/scripts/install-sdm.sh")
}

resource "coder_script" "listen" {
  agent_id     = var.agent_id
  display_name = "Start StrongDM Listener"
  icon         = "/icon/database.svg"
  run_on_start = true
  script       = file("${path.module}/scripts/sdm-listen.sh")
}
