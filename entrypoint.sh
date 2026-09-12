#!/bin/bash
set -uo pipefail

XRAY_CONFIG=/etc/xray/config.json

start_xray() {
    echo "[+] Starting Xray Core..."
    xray run -config "$XRAY_CONFIG" &
    XRAY_PID=$!
}

# Watchdog: if Xray ever dies (bad config, transient crash, whatever), log
# it loudly and restart it — but never bring the container down over it.
# Cloud Run's startup probe only checks that port 8080 (the reverse proxy,
# below) is accepting connections; if this script's own exit takes the
# proxy down with it, that reproduces "container failed to start and
# listen on PORT" even when the actual problem is isolated to Xray.
watchdog() {
    while true; do
        wait "$XRAY_PID" 2>/dev/null
        echo "[!] Xray Core exited unexpectedly — restarting in 2s. Xray's own error output should be just above this line; check ${XRAY_CONFIG} if it points to a config problem." >&2
        sleep 2
        start_xray
    done
}

start_xray
watchdog &

# Select Proxy Engine. This is exec'd directly (becomes PID 1) so it starts
# and binds :8080 immediately and reliably, and so it receives SIGTERM
# straight from the platform on shutdown instead of it being swallowed by
# an intermediate shell.
ENGINE="${PROXY_ENGINE:-openresty}"
echo "[+] Starting Reverse Proxy Engine: $ENGINE"

case "$ENGINE" in
  "envoy")
    exec envoy -c /etc/envoy/envoy.yaml
    ;;
  "haproxy")
    exec haproxy -f /etc/haproxy/haproxy.cfg
    ;;
  "openresty"|*)
    exec openresty -g "daemon off;"
    ;;
esac
