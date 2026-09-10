#!/bin/bash
set -e

# Start Xray Core in background
echo "[+] Starting Xray Core..."
xray run -config /etc/xray/config.json &
XRAY_PID=$!

# Give Xray a moment to parse its config and bind its ports, then confirm
# it's actually alive. Previously the script pressed on regardless, so a
# bad config.json meant every inbound port was refused/EOF even though the
# container reported a healthy deploy.
sleep 2
if ! kill -0 "$XRAY_PID" 2>/dev/null; then
    echo "[!] FATAL: Xray Core exited immediately — check /etc/xray/config.json" >&2
    exit 1
fi
echo "[+] Xray Core is up (pid $XRAY_PID)"

# Select Proxy Engine
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

# If either process dies, bring the whole container down so the platform
# restarts it, rather than limping along with only half the pipeline up.
wait -n "$XRAY_PID" "$PROXY_PID"
EXIT_CODE=$?
echo "[!] A child process exited (code $EXIT_CODE) — shutting down container." >&2
kill "$XRAY_PID" "$PROXY_PID" 2>/dev/null || true
exit "$EXIT_CODE"
