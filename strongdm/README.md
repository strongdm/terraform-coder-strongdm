# StrongDM

Install the [StrongDM](https://www.strongdm.com) CLI in a workspace and sign it in as the workspace owner, with the StrongDM token they linked in Coder. No StrongDM credential is stored in the template or the workspace.

```hcl
module "strongdm" {
  count     = data.coder_workspace.me.start_count
  source    = "git::https://github.com/<org>/<repo>//strongdm?ref=v0.1.0"
  agent_id  = coder_agent.main.id
  client_id = "..."
}
```

## Prerequisites

- A StrongDM Coder integration. Its client ID is the module's `client_id`. It is not a secret.
- An external auth provider in Coder with the ID `strongdm` and the same client ID. Each developer links StrongDM once, under **Account > External Authentication**.
- A Linux amd64 or arm64 workspace with `curl`, `unzip`, `sha256sum`, `sed` and `awk`, that can reach `app.strongdm.com` and `downloads.strongdm.com`.

## How it works

At every start the module asks StrongDM for the CLI release that matches the workspace's architecture, downloads it, checks it against the SHA-256 that StrongDM publishes for that release, and installs it with the coder CLI in `~/.local/bin`. It then runs `sdm listen` in the background. The listener gets the owner's token from Coder, exchanges it for a short StrongDM session and, unless `connect_all = false`, connects every resource the owner can use.

If the owner unlinks StrongDM in Coder, or StrongDM refuses the token, the listener stops and waits until they link it again. Its log is `~/.coder-modules/strongdm/strongdm/logs/listen.log`.

## CLI version

The module installs StrongDM CLI 56.36.0, the first release that can sign in through Coder. Set `sdm_version` to pin another release, or to `"latest"` for StrongDM's current release. Each workspace looks the release up when it starts, so with `"latest"` it upgrades at its next start after StrongDM ships one. If the release doesn't exist or is older than 56.36.0, the **Install StrongDM CLI** step fails with a clear error in the workspace's startup log.

## Examples

### Pin the CLI version

```hcl
module "strongdm" {
  count       = data.coder_workspace.me.start_count
  source      = "git::https://github.com/<org>/<repo>//strongdm?ref=v0.1.0"
  agent_id    = coder_agent.main.id
  client_id   = "..."
  sdm_version = "56.36.0"
}
```

### Sign in without connecting resources

```hcl
module "strongdm" {
  count       = data.coder_workspace.me.start_count
  source      = "git::https://github.com/<org>/<repo>//strongdm?ref=v0.1.0"
  agent_id    = coder_agent.main.id
  client_id   = "..."
  connect_all = false
}
```
