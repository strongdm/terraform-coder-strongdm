# StrongDM's release endpoint, as it answers for 56.36.0 on linux/amd64.
override_data {
  target = data.http.sdm_cli
  values = {
    status_code   = 200
    response_body = "{\"url\":\"https://downloads.strongdm.com/builds/sdm-cli/56.36.0/linux-amd64/FF87F494D697544341974DF6A19CB983FC25CB15/sdmcli_56.36.0_linux_amd64.zip\",\"version\":\"56.36.0\",\"sha256\":\"6F850B2EA38E30B5AE4142AB33839772E8B7D1ABCB7B55A6773DDD3BAA804E20\",\"software\":\"sdm-cli\",\"os\":\"linux\",\"arch\":\"amd64\"}"
  }
}

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
    condition     = data.http.sdm_cli.url == "https://app.strongdm.com/release?software=sdm-cli&os=linux&arch=amd64&version=56.36.0"
    error_message = "the release lookup must default to 56.36.0 on linux/amd64 at app.strongdm.com"
  }

  assert {
    condition     = resource.coder_env.strongdm["SDM_CLI_URL"].value == "https://downloads.strongdm.com/builds/sdm-cli/56.36.0/linux-amd64/FF87F494D697544341974DF6A19CB983FC25CB15/sdmcli_56.36.0_linux_amd64.zip"
    error_message = "SDM_CLI_URL must come from the release endpoint"
  }

  assert {
    condition     = resource.coder_env.strongdm["SDM_CLI_SHA256"].value == "6f850b2ea38e30b5ae4142ab33839772e8b7d1abcb7b55a6773ddd3baa804e20"
    error_message = "SDM_CLI_SHA256 must be the endpoint's checksum in lower case, as sha256sum prints it"
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
    error_message = "logs must follow the registry's module data layout"
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
    sdm_version    = "56.40.1"
    arch           = "arm64"
    sdm_app_domain = "app.uk.strongdm.com"
    home           = "/home/dev"
    connect_all    = false
  }

  assert {
    condition     = data.http.sdm_cli.url == "https://app.uk.strongdm.com/release?software=sdm-cli&os=linux&arch=arm64&version=56.40.1"
    error_message = "the release lookup must use sdm_app_domain, arch and sdm_version"
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

run "unknown_release" {
  command = plan

  variables {
    agent_id    = "foo"
    client_id   = "client-123"
    sdm_version = "1.2.3"
  }

  override_data {
    target = data.http.sdm_cli
    values = {
      status_code   = 404
      response_body = "not found"
    }
  }

  expect_failures = [data.http.sdm_cli]
}

run "client_id_required" {
  command = plan

  variables {
    agent_id  = "foo"
    client_id = " "
  }

  expect_failures = [var.client_id]
}

run "arch_rejected" {
  command = plan

  variables {
    agent_id  = "foo"
    client_id = "client-123"
    arch      = "386"
  }

  expect_failures = [var.arch]
}

run "sdm_version_rejected" {
  command = plan

  variables {
    agent_id    = "foo"
    client_id   = "client-123"
    sdm_version = "latest"
  }

  expect_failures = [var.sdm_version]
}
