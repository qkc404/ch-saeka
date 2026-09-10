#!/bin/bash
set -e

# Dynamically bind PORT assigned by Cloud Run (defaults to 8080)
RUN_PORT="${PORT:-8080}"

echo "[+] Configuring server to listen on port: $RUN_PORT"
sed -i "s/8080/$RUN_PORT/g" /usr/local/openresty/nginx/conf/nginx.conf 2>/dev/null || true
sed -i "s/8080/$RUN_PORT/g" /etc/envoy/envoy.yaml 2>/dev/null || true
sed -i "s/8080/$RUN_PORT/g" /etc/haproxy/haproxy.cfg 2>/dev/null || true

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
