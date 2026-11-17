#!/bin/sh
# Starts MTProxy and the dashboard. Shared by the Docker image and the WSL host (GO form).
#
# Settings (environment):
#   PROXY_PORT        port clients connect to (default 443)
#   DASHBOARD_PORT    dashboard port (default 8080)
#   DASHBOARD_PASSWORD  required, 8+ characters
#   TLS_DOMAIN        optional: disguise the proxy as HTTPS to this domain (fake TLS)
#   PROXY_TAG         optional: promotion tag from @MTProxybot
#   PUBLIC_HOST       optional: address put in the share link (default: first LAN address)
#   WORKERS           MTProxy workers (default 1)
#   DATA_DIR          where the secret and Telegram's proxy config live (default /data)
set -eu

DATA_DIR="${DATA_DIR:-/data}"
PROXY_PORT="${PROXY_PORT:-443}"
DASHBOARD_PORT="${DASHBOARD_PORT:-8080}"
WORKERS="${WORKERS:-1}"
MTPROXY_BIN="${MTPROXY_BIN:-/usr/local/bin/mtproto-proxy}"
DASHBOARD_DIR="${DASHBOARD_DIR:-/opt/dashboard}"
mkdir -p "$DATA_DIR"

log() { printf '%s %-9s %s\n' "$(date +%H:%M:%S)" "$1" "$2"; }

if [ -z "${DASHBOARD_PASSWORD:-}" ] && [ -f "$DATA_DIR/dashboard-password" ]; then
  IFS= read -r DASHBOARD_PASSWORD < "$DATA_DIR/dashboard-password" || true
fi
if [ -z "${DASHBOARD_PASSWORD:-}" ] || [ "${#DASHBOARD_PASSWORD}" -lt 8 ]; then
  log entry "DASHBOARD_PASSWORD is missing or shorter than 8 characters. Set it and start again."
  exit 64
fi

# The client secret: made once, kept in the data volume, never printed.
if [ ! -s "$DATA_DIR/secret" ]; then
  head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$DATA_DIR/secret"
  chmod 600 "$DATA_DIR/secret"
  log entry "made a new client secret"
fi

fetch_config() {
  # Telegram's own files: the key MTProxy uses to talk to Telegram, and the data centre list.
  curl -fsS --max-time 30 https://core.telegram.org/getProxySecret -o "$DATA_DIR/proxy-secret.new" \
    && curl -fsS --max-time 30 https://core.telegram.org/getProxyConfig -o "$DATA_DIR/proxy-multi.conf.new" \
    && [ -s "$DATA_DIR/proxy-secret.new" ] && [ -s "$DATA_DIR/proxy-multi.conf.new" ] \
    && mv "$DATA_DIR/proxy-secret.new" "$DATA_DIR/proxy-secret" \
    && mv "$DATA_DIR/proxy-multi.conf.new" "$DATA_DIR/proxy-multi.conf"
}

if fetch_config; then
  log proxy "fetched Telegram proxy configuration ($(grep -c '^proxy_for' "$DATA_DIR/proxy-multi.conf") routes)"
elif [ -s "$DATA_DIR/proxy-multi.conf" ]; then
  log proxy "could not refresh configuration, using the saved copy"
else
  log proxy "could not fetch Telegram proxy configuration and no saved copy exists"
  exit 69
fi

IFS= read -r SECRET < "$DATA_DIR/secret" || true
# --http-stats: without it this build never opens the loopback stats port the dashboard reads.
set -- -u nobody -p 8888 --http-stats -H "$PROXY_PORT" -S "$SECRET" --aes-pwd "$DATA_DIR/proxy-secret" "$DATA_DIR/proxy-multi.conf" -M "$WORKERS"
if [ -n "${PROXY_TAG:-}" ]; then set -- "$@" -P "$PROXY_TAG"; fi
if [ -n "${TLS_DOMAIN:-}" ]; then set -- "$@" -D "$TLS_DOMAIN"; fi

# Supervise MTProxy: restart it within a minute if it stops, and refresh Telegram's
# configuration once a day, restarting only when the configuration actually changed.
PROXY_LOG="$DATA_DIR/proxy.log"
: > "$PROXY_LOG"
tail -n0 -F "$PROXY_LOG" 2>/dev/null | while IFS= read -r line; do log proxy "$line"; done &

run_proxy() {
  proxy_pid=""
  last_refresh="$(date +%s)"
  while true; do
    if [ -z "$proxy_pid" ] || ! kill -0 "$proxy_pid" 2>/dev/null; then
      [ -n "$proxy_pid" ] && log proxy "MTProxy stopped, starting it again"
      "$MTPROXY_BIN" "$@" >> "$PROXY_LOG" 2>&1 &
      proxy_pid=$!
      echo "$proxy_pid" > "$DATA_DIR/proxy.pid"
      log proxy "listening on 0.0.0.0:$PROXY_PORT, stats on 127.0.0.1:8888"
    fi
    now="$(date +%s)"
    if [ $((now - last_refresh)) -ge 86400 ]; then
      last_refresh="$now"
      old="$(cksum < "$DATA_DIR/proxy-multi.conf")"
      if fetch_config && [ "$(cksum < "$DATA_DIR/proxy-multi.conf")" != "$old" ]; then
        log proxy "configuration changed, restarting"
        kill "$proxy_pid" 2>/dev/null || true
        wait "$proxy_pid" 2>/dev/null || true
        proxy_pid=""
        continue
      fi
      log proxy "configuration checked, unchanged"
    fi
    sleep 60
  done
}

run_proxy "$@" &

export DATA_DIR PROXY_PORT DASHBOARD_PORT DASHBOARD_PASSWORD
export TLS_DOMAIN="${TLS_DOMAIN:-}" PUBLIC_HOST="${PUBLIC_HOST:-}" MTPROXY_COMMIT="${MTPROXY_COMMIT:-unknown}"
exec node "$DASHBOARD_DIR/server.js"
