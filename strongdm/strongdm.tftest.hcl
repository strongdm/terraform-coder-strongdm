override_data {
  target = data.coder_workspace.me
  values = {
    access_url = "https://coder.example.com"
  }
}

run "required_vars" {
  command = plan

  variables {
    agent_id  = "foo"
    client_id = "client-123"
  }

  assert {
    condition     = resource.coder_env.strongdm["STRONGDM_CLI_VERSION"].value == "56.36.0"
    error_message = "the CLI version must default to 56.36.0"
  }

  assert {
    condition     = resource.coder_env.strongdm["STRONGDM_CLIENT_ID"].value == "client-123"
    error_message = "STRONGDM_CLIENT_ID must be client_id"
  }

  assert {
    condition     = resource.coder_env.strongdm["SDM_APP_DOMAIN"].value == "app.strongdm.com"
    error_message = "SDM_APP_DOMAIN must default to app.strongdm.com"
  }

  assert {
    condition     = resource.coder_env.strongdm["SDM_HOME"].value == "/home/coder/.sdm"
    error_message = "SDM_HOME must be under the default home"
  }

  assert {
    condition     = resource.coder_env.strongdm["SDM_CREDENTIAL_FILE"].value == "/home/coder/.config/strongdm/coder-source.json"
    error_message = "the credential source must be under the user's home, never /tmp"
  }

  assert {
    condition     = resource.coder_env.strongdm["STRONGDM_LOG_DIR"].value == "/home/coder/.coder-modules/strongdm/strongdm/logs"
    error_message = "logs must be under ~/.coder-modules/strongdm/strongdm"
  }

  assert {
    condition     = resource.coder_env.strongdm["STRONGDM_CONNECT_ALL"].value == "true"
    error_message = "connect_all must default to true"
  }

  assert {
    condition     = resource.coder_env.strongdm["CODER_AGENT_URL"].value == "https://coder.example.com"
    error_message = "CODER_AGENT_URL must be the deployment's access URL"
  }

  assert {
    condition     = resource.coder_env.strongdm["STRONGDM_PROVIDER_ID"].value == "strongdm"
    error_message = "the provider ID must default to strongdm"
  }

  assert {
    condition     = length(resource.coder_env.strongdm) == 9
    error_message = "the module must set exactly the documented environment"
  }

  assert {
    condition     = alltrue([for e in resource.coder_env.strongdm : e.agent_id == "foo"])
    error_message = "every variable must target agent_id"
  }
}

run "scripts" {
  command = plan

  variables {
    agent_id  = "foo"
    client_id = "client-123"
  }

  assert {
    condition     = resource.coder_script.install.script == file("${path.module}/scripts/install-sdm.sh")
    error_message = "the install script must be scripts/install-sdm.sh"
  }

  assert {
    condition     = resource.coder_script.install.run_on_start && resource.coder_script.install.start_blocks_login
    error_message = "the CLI must be installed before the owner logs in"
  }

  assert {
    condition     = strcontains(file("${path.module}/scripts/install-sdm.sh"), "\"$STRONGDM_PROVIDER_ID\"") && !strcontains(file("${path.module}/scripts/install-sdm.sh"), "access-token\", \"strongdm\"")
    error_message = "the credential source must use the configured provider ID, not a fixed one"
  }

  assert {
    condition     = strcontains(file("${path.module}/scripts/sdm-listen.sh"), "access-token \"$STRONGDM_PROVIDER_ID\"") && !strcontains(file("${path.module}/scripts/sdm-listen.sh"), "access-token strongdm")
    error_message = "the listener must use the configured provider ID, not a fixed one"
  }

  assert {
    condition     = resource.coder_script.listen.script == file("${path.module}/scripts/sdm-listen.sh")
    error_message = "the listener script must be scripts/sdm-listen.sh"
  }

  assert {
    condition     = resource.coder_script.listen.run_on_start && !resource.coder_script.listen.start_blocks_login
    error_message = "the listener must start with the workspace without blocking login"
  }
}

run "custom_inputs" {
  command = plan

  variables {
    agent_id       = "foo"
    client_id      = "client-123"
    sdm_version    = "latest"
    sdm_app_domain = "app.uk.strongdm.com"
    home           = "/home/dev"
    connect_all    = false
    provider_id    = "strongdm-qa"
  }

  assert {
    condition     = resource.coder_env.strongdm["STRONGDM_PROVIDER_ID"].value == "strongdm-qa"
    error_message = "STRONGDM_PROVIDER_ID must be provider_id"
  }

  assert {
    condition     = resource.coder_env.strongdm["STRONGDM_CLI_VERSION"].value == "latest"
    error_message = "STRONGDM_CLI_VERSION must be sdm_version"
  }

  assert {
    condition     = resource.coder_env.strongdm["SDM_APP_DOMAIN"].value == "app.uk.strongdm.com"
    error_message = "SDM_APP_DOMAIN must be sdm_app_domain"
  }

  assert {
    condition     = resource.coder_env.strongdm["SDM_HOME"].value == "/home/dev/.sdm"
    error_message = "SDM_HOME must follow home"
  }

  assert {
    condition     = resource.coder_env.strongdm["SDM_CREDENTIAL_FILE"].value == "/home/dev/.config/strongdm/coder-source.json"
    error_message = "SDM_CREDENTIAL_FILE must follow home"
  }

  assert {
    condition     = resource.coder_env.strongdm["STRONGDM_LOG_DIR"].value == "/home/dev/.coder-modules/strongdm/strongdm/logs"
    error_message = "STRONGDM_LOG_DIR must follow home"
  }

  assert {
    condition     = resource.coder_env.strongdm["STRONGDM_CONNECT_ALL"].value == "false"
    error_message = "STRONGDM_CONNECT_ALL must be false when connect_all is false"
  }
}

run "client_id_required" {
  command = plan

  variables {
    agent_id  = "foo"
    client_id = " "
  }

  expect_failures = [var.client_id]
}

run "sdm_version_rejected" {
  command = plan

  variables {
    agent_id    = "foo"
    client_id   = "client-123"
    sdm_version = "newest"
  }

  expect_failures = [var.sdm_version]
}

run "provider_id_with_underscore_rejected" {
  command = plan

  variables {
    agent_id    = "foo"
    client_id   = "client-123"
    provider_id = "strongdm_qa"
  }

  expect_failures = [var.provider_id]
}

run "provider_id_reserved_rejected" {
  command = plan

  variables {
    agent_id    = "foo"
    client_id   = "client-123"
    provider_id = "create"
  }

  expect_failures = [var.provider_id]
}

run "provider_id_too_long_rejected" {
  command = plan

  variables {
    agent_id    = "foo"
    client_id   = "client-123"
    provider_id = "abcdefghijklmnopqrstuvwxyz0123456"
  }

  expect_failures = [var.provider_id]
}

run "provider_id_with_double_hyphen_rejected" {
  command = plan

  variables {
    agent_id    = "foo"
    client_id   = "client-123"
    provider_id = "strongdm--qa"
  }

  expect_failures = [var.provider_id]
}
