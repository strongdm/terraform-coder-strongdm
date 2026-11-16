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

case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *)
    echo "StrongDM has no Linux CLI for $(uname -m)" >&2
    exit 1
    ;;
esac

# Signing in through Coder (credential-source mode) needs this CLI or later.
min_version=56.36.0

# StrongDM's release endpoint gives the zip's URL, version and SHA-256 for
# this architecture: the current release, or STRONGDM_CLI_VERSION when it's pinned.
query="software=sdm-cli&os=linux&arch=$arch"
[ "$STRONGDM_CLI_VERSION" = latest ] || query="$query&version=$STRONGDM_CLI_VERSION"
release=$(curl -fsSL "https://$SDM_APP_DOMAIN/release?$query") || {
  echo "StrongDM has no Linux $arch CLI release $STRONGDM_CLI_VERSION" >&2
  exit 1
}
field() { printf '%s' "$release" | sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p"; }
url=$(field url)
version=$(field version)
sha256=$(field sha256 | tr 'A-F' 'a-f')
if [ -z "$url" ] || [ -z "$version" ] || [ -z "$sha256" ]; then
  echo "Unexpected answer from StrongDM's release endpoint: $release" >&2
  exit 1
fi

# True when version $1 is older than $2.
older() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    split(a, x, "."); split(b, y, ".")
    for (i = 1; i <= 3; i++) {
      if (x[i] + 0 < y[i] + 0) exit 0
      if (x[i] + 0 > y[i] + 0) exit 1
    }
    exit 1
  }'
}
if older "$version" "$min_version"; then
  echo "StrongDM CLI $version can't sign in through Coder: it needs $min_version or later. Set sdm_version to $min_version or later." >&2
  exit 1
fi

# The CLI, checked against its published SHA-256.
tmp=$(mktemp -d)
curl -fsSL -o "$tmp/sdm.zip" "$url"
echo "$sha256  $tmp/sdm.zip" | sha256sum -c --quiet
unzip -oq "$tmp/sdm.zip" sdm -d "$tmp"
install -m 700 "$tmp/sdm" "$bin/sdm"
rm -rf "$tmp"

# The coder CLI that matches the server, as a regular file: sdm won't run
# the agent's own copy in /tmp.
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
    "args": ["external-auth", "access-token", "$STRONGDM_PROVIDER_ID", "--output", "json"],
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
