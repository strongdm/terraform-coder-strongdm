# StrongDM for Coder workspaces

A Terraform module for Coder templates. In every workspace it installs the StrongDM CLI, signs it in as the workspace owner, and connects the resources they can use in StrongDM: databases, servers, Kubernetes clusters and websites.

Developers sign in once, by linking StrongDM to their Coder account. No StrongDM credential is stored in the template or the workspace.

## How it works

1. A developer links StrongDM under **Account > External Authentication** in Coder. Coder keeps their StrongDM token.
2. When a workspace starts, the module installs the StrongDM CLI (`sdm`) and the coder CLI in `~/.local/bin`.
3. It starts `sdm listen` in the background. The listener gets the owner's token from Coder, exchanges it for a short StrongDM session and connects every resource they can use.

If StrongDM refuses the owner's token, for example after they unlink StrongDM in Coder, the listener stops and waits until they link it again.

## Requirements

- StrongDM's Coder integration for your organization.
- Access to your Coder server's configuration, to add StrongDM as an external auth provider.
- Linux amd64 or arm64 workspaces with `curl`, `unzip`, `sha256sum`, `sed` and `awk`. Many minimal images lack `unzip`.
- Network access from workspaces to `app.strongdm.com`, `downloads.strongdm.com` and your Coder access URL.

## Setup

### 1. Create the Coder integration in StrongDM

In the StrongDM Admin UI, go to **Settings > Integrations > Coder** and add an integration with this callback URL:

```text
https://<your Coder access URL>/external-auth/strongdm/callback
```

StrongDM gives you a client ID, a client secret, and authorize, token and revoke URLs.

### 2. Add StrongDM to Coder

Set these on the Coder server and restart it. Use the next free index if you already have external auth providers.

```bash
CODER_EXTERNAL_AUTH_0_ID=strongdm
CODER_EXTERNAL_AUTH_0_TYPE=strongdm
CODER_EXTERNAL_AUTH_0_DISPLAY_NAME=StrongDM
CODER_EXTERNAL_AUTH_0_CLIENT_ID=<client ID>
CODER_EXTERNAL_AUTH_0_CLIENT_SECRET=<client secret>
CODER_EXTERNAL_AUTH_0_AUTH_URL=<authorize URL>
CODER_EXTERNAL_AUTH_0_TOKEN_URL=<token URL>
CODER_EXTERNAL_AUTH_0_REVOKE_URL=<revoke URL>
CODER_EXTERNAL_AUTH_0_PKCE_METHODS=S256
```

The ID must be `strongdm`: the module asks Coder for the token by that name. Keep the client secret in your secret store. Only the Coder server needs it.

### 3. Add the module to your template

```hcl
module "strongdm" {
  count     = data.coder_workspace.me.start_count
  source    = "git::https://github.com/strongdm/terraform-coder-strongdm//strongdm?ref=v0.1.0"
  agent_id  = coder_agent.main.id
  client_id = "<client ID>"
}
```

`client_id` is the same client ID as in step 2. It identifies the integration and is not a secret.

If the workspace user's home isn't `/home/coder`, set `home`. Then push the template.

### 4. Link StrongDM

Each developer links StrongDM once, under **Account > External Authentication** in Coder. Workspaces that start before they link wait, and sign in as soon as they do.

## Check that it works

In a workspace terminal:

```bash
sdm status
```

It lists the resources the developer can use, with the local port each one is connected on. The listener's log is `~/.coder-modules/strongdm/strongdm/logs/listen.log`.

## Configuration

| Input            | Default              | Description                                                                                                     |
| ---------------- | -------------------- | --------------------------------------------------------------------------------------------------------------- |
| `agent_id`       | required             | The Coder agent to install into.                                                                                |
| `client_id`      | required             | Client ID of the StrongDM Coder integration.                                                                    |
| `sdm_version`    | `"56.36.0"`          | StrongDM CLI release to install, or `"latest"`.                                                                 |
| `sdm_app_domain` | `"app.strongdm.com"` | StrongDM control plane.                                                                                         |
| `home`           | `"/home/coder"`      | Home directory of the workspace user.                                                                           |
| `connect_all`    | `true`               | Connect every resource once the listener is up. Set `false` to connect resources one by one with `sdm connect`. |

### CLI version

Signing in through Coder needs StrongDM CLI 56.36.0 or later, so the module installs 56.36.0 by default. Set `sdm_version` to pin another release, or to `"latest"` for StrongDM's current release.

Each workspace looks the release up when it starts. With `"latest"`, it upgrades at its next start after StrongDM ships a release. A release older than 56.36.0 is refused.

## Troubleshooting

Errors from the install appear in the **Install StrongDM CLI** step of the workspace's startup logs. The listener writes to `~/.coder-modules/strongdm/strongdm/logs/listen.log`.

| You see                                                                 | What to do                                                                                                                     |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `StrongDM CLI … can't sign in through Coder: it needs 56.36.0 or later` | StrongDM's current release is older than 56.36.0. Set `sdm_version = "56.36.0"`.                                               |
| `StrongDM has no Linux … CLI release …`                                 | `sdm_version` isn't a StrongDM release. Check the number.                                                                      |
| `StrongDM has no Linux CLI for …`                                       | The workspace isn't amd64 or arm64.                                                                                            |
| `waiting for StrongDM to be linked in Coder` in the log                 | The owner hasn't linked StrongDM, or their link was revoked. They link it under **Account > External Authentication**.         |
| `curl` errors during install                                            | The workspace can't reach `app.strongdm.com`, `downloads.strongdm.com` or the Coder access URL.                                |
| `sdm: command not found`                                                | Open a new terminal. The module adds `~/.local/bin` to `PATH` in `~/.bashrc`; other shells need it added to their own profile. |

## Security

- The workspace holds no StrongDM credential. The listener asks Coder for the owner's token each time it needs one.
- The CLI's credential file, `~/.config/strongdm/coder-source.json`, holds only the client ID and the command that asks Coder for the token.
- The CLI download is checked against the SHA-256 that StrongDM publishes for that release.
- The two CLIs and the credential file are readable only by the workspace user.
