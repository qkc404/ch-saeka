#!/bin/bash
set -e

# Start Xray Core in background
echo "[+] Starting Xray Core..."
xray run -config /etc/xray/config.json &

# Select Proxy Engine
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
