#!/bin/sh
# Installs the StrongDM CLI and the coder CLI, and writes the credential
# source that tells sdm how to get the workspace owner's token from Coder.
# Runs at every workspace start. Settings come from coder_env (main.tf).
set -eu
umask 077

bin="$HOME/.local/bin"
source_dir=$(dirname "$SDM_CREDENTIAL_FILE")

# sdm only runs a credential source from paths no one else can write to.
mkdir -p "$bin" "$source_dir" "$SDM_HOME"
chmod 700 "$HOME/.local" "$bin" "$HOME/.config" "$source_dir" "$SDM_HOME"

# The pinned StrongDM CLI, checked against its published SHA-256.
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/sdm.zip" "$SDM_CLI_URL"
echo "$SDM_CLI_SHA256  $tmp/sdm.zip" | sha256sum -c --quiet
unzip -oq "$tmp/sdm.zip" sdm -d "$tmp"
install -m 700 "$tmp/sdm" "$bin/sdm"
rm -rf "$tmp"

# The coder CLI that matches the server, as a regular file: sdm won't run
# the agent's own copy in /tmp.
case "$(uname -m)" in
  aarch64 | arm64) arch=arm64 ;;
  *) arch=amd64 ;;
esac
curl -fsSL -o "$bin/coder.new" "$CODER_AGENT_URL/bin/coder-linux-$arch"
chmod 700 "$bin/coder.new"
mv "$bin/coder.new" "$bin/coder"

# Holds no secret: the client ID and the command that prints the token.
cat > "$SDM_CREDENTIAL_FILE.new" << EOF
{
  "version": 1,
  "client_id": "$STRONGDM_CLIENT_ID",
  "executable": {
    "command": "$bin/coder",
    "args": ["external-auth", "access-token", "strongdm", "--output", "json"],
    "timeout_seconds": 10
  },
  "format": {
    "type": "json",
    "subject_token_field_name": "access_token",
    "expiration_field_name": "expires_at"
  }
}
EOF
chmod 600 "$SDM_CREDENTIAL_FILE.new"
mv "$SDM_CREDENTIAL_FILE.new" "$SDM_CREDENTIAL_FILE"

grep -qs '.local/bin' "$HOME/.bashrc" \
  || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

"$bin/sdm" --version
