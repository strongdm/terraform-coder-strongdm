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

- A StrongDM Coder integration, which gives you the `client_id`.
- An external auth provider in Coder with the ID `strongdm` that points at that integration. Each developer links StrongDM once, under **Account > External Authentication**.
- A Linux workspace with `curl`, `unzip` and `sha256sum`.

## How it works

At every start the module downloads the pinned StrongDM CLI, checks it against the SHA-256 that StrongDM publishes for that release, and installs it with the coder CLI in `~/.local/bin`. It then runs `sdm listen` in the background. The listener gets the owner's token from Coder, exchanges it for a short StrongDM session and, unless `connect_all = false`, connects every resource the owner can use.

If the owner unlinks StrongDM in Coder, or StrongDM refuses the token, the listener stops and waits until they link it again. Its log is `~/.coder-modules/strongdm/strongdm/logs/listen.log`.

## Examples

### Pin a CLI version on arm64

```hcl
module "strongdm" {
  count       = data.coder_workspace.me.start_count
  source      = "git::https://github.com/<org>/<repo>//strongdm?ref=v0.1.0"
  agent_id    = coder_agent.main.id
  client_id   = "..."
  sdm_version = "56.36.0"
  arch        = "arm64"
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
