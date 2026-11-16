#!/bin/sh
# Keeps `sdm listen` running as the workspace owner and, unless
# STRONGDM_CONNECT_ALL is false, connects every resource they can use.
# Log: $STRONGDM_LOG_DIR/listen.log.
#
# sdm exits with 78 when StrongDM refuses or revokes the token, for example
# after the owner unlinks StrongDM in Coder. That token would only fail
# again, so the script waits for a new one: the owner links StrongDM again.
set -u
PATH="$HOME/.local/bin:$PATH"

log() { echo "$(date -Is) $*"; }

# A fingerprint of the owner's token, empty when StrongDM isn't linked.
# The token itself is a bearer credential and is never printed.
token_id() {
  token=$(coder external-auth access-token "$STRONGDM_PROVIDER_ID" --output json 2> /dev/null) \
    && printf '%s' "$token" | sha256sum | cut -c1-16
}

# Waits until Coder has a token for the owner other than $1.
wait_for_token() {
  until id=$(token_id) && [ "$id" != "$1" ]; do
    log "waiting for StrongDM to be linked in Coder (Account > External Authentication)"
    sleep 15
  done
}

main() {
  trap '' HUP
  until [ -x "$HOME/.local/bin/sdm" ] && [ -f "$SDM_CREDENTIAL_FILE" ]; do sleep 2; done

  refused=""
  while :; do
    wait_for_token "$refused"
    current=$(token_id)

    # Once the listener answers, open a local port for every resource.
    connector=""
    if [ "$STRONGDM_CONNECT_ALL" = true ]; then
      (
        until sdm status > /dev/null 2>&1; do sleep 2; done
        log "connecting all resources"
        sdm connect --all || log "sdm connect --all failed"
      ) &
      connector=$!
    fi

    log "starting sdm listen"
    sdm listen
    status=$?
    [ -z "$connector" ] || kill "$connector" 2> /dev/null
    log "sdm listen exited with $status"

    if [ "$status" -eq 78 ]; then
      refused=$current
    else
      refused=""
      sleep 10
    fi
  done
}

# Coder waits for start scripts to finish and for their output to close, so
# the listener runs in the background with its output in the log. `exec`
# matters: redirecting the call itself would keep Coder's pipes open.
mkdir -p "$STRONGDM_LOG_DIR"
(
  exec >> "$STRONGDM_LOG_DIR/listen.log" 2>&1 < /dev/null
  main
) &
