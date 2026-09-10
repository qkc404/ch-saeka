#!/bin/bash
set -e

echo "[+] Starting Xray Core..."
xray run -config /etc/xray/config.json &
XRAY_PID=$!

# Wait up to 15s for Xray to be ready on the primary port
for i in {1..15}; do
  if nc -z 127.0.0.1 10000 2>/dev/null; then
    echo "[+] Xray READY on port 10000"
    break
  fi
  echo "⏳ Waiting for Xray socket to bind... ($i/15)"
  sleep 1
done

if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "[!] FATAL: Xray Core crashed during startup. Check /etc/xray/config.json" >&2
    exit 1
fi
echo "[+] Xray Core is fully operational (pid $XRAY_PID)"

ENGINE="${PROXY_ENGINE:-openresty}"
echo "[+] Starting Reverse Proxy Engine: $ENGINE"

case "$ENGINE" in
  "envoy")
    envoy -c /etc/envoy/envoy.yaml &
    ;;
  "haproxy")
    haproxy -f /etc/haproxy/haproxy.cfg &
    ;;
  "openresty"|*)
    openresty -g "daemon off;" &
    ;;
esac
PROXY_PID=$!

wait -n "$XRAY_PID" "$PROXY_PID"
EXIT_CODE=$?
echo "[!] A child process exited (code $EXIT_CODE) — shutting down container." >&2
kill "$XRAY_PID" "$PROXY_PID" 2>/dev/null || true
exit "$EXIT_CODE"
