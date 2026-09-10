#!/bin/bash
set -euo pipefail

# =========================================
# ENTRYPOINT - XRAY + OPENRESTY ORCHESTRATION
# Google Cloud Run optimized - bash built-in socket checks
# =========================================

trap 'handle_signal' SIGTERM SIGINT

handle_signal() {
    echo "[!] Received shutdown signal. Terminating processes..."
    kill "$XRAY_PID" 2>/dev/null || true
    kill "$PROXY_PID" 2>/dev/null || true
    sleep 2
    pkill -9 xray 2>/dev/null || true
    pkill -9 nginx 2>/dev/null || true
    pkill -9 openresty 2>/dev/null || true
    exit 0
}

# Function to check if port is listening using bash /dev/tcp
check_port() {
    local port=$1
    (echo >/dev/tcp/127.0.0.1/$port) 2>/dev/null && return 0 || return 1
}

# ===== XRAY STARTUP =====
echo "[+] Initializing Xray Core..."
xray run -config /etc/xray/config.json > /tmp/xray.log 2>&1 &
XRAY_PID=$!
echo "[+] Xray process ID: $XRAY_PID"

# Wait for Xray to bind on inbound ports
echo "[*] Waiting for Xray inbound sockets to bind..."
XRAY_PORTS=(10000 10001 10002)
READY=0

for attempt in {1..30}; do
    PORTS_READY=0
    for PORT in "${XRAY_PORTS[@]}"; do
        if check_port "$PORT"; then
            ((PORTS_READY++))
        fi
    done
    
    if [ "$PORTS_READY" -ge 3 ]; then
        READY=1
        echo "[✓] Xray ready on $PORTS_READY core ports"
        break
    fi
    
    if ! kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "[!] ERROR: Xray process exited unexpectedly!"
        cat /tmp/xray.log 2>/dev/null | tail -30 || echo "No xray logs"
        exit 1
    fi
    
    sleep 0.5
done

if [ $READY -eq 0 ]; then
    echo "[!] WARNING: Xray startup incomplete (only $PORTS_READY / 3 ports ready)"
    cat /tmp/xray.log 2>/dev/null | tail -20 || echo "No xray logs"
fi

echo "[✓] Xray Core operational"

# ===== PROXY ENGINE STARTUP =====
ENGINE="${PROXY_ENGINE:-openresty}"
echo "[+] Starting Reverse Proxy Engine: $ENGINE"

case "$ENGINE" in
    "envoy")
        echo "[+] Launching Envoy Proxy..."
        envoy -c /etc/envoy/envoy.yaml > /tmp/envoy.log 2>&1 &
        PROXY_PID=$!
        PROXY_PORT=8080
        ;;
    "haproxy")
        echo "[+] Launching HAProxy..."
        haproxy -f /etc/haproxy/haproxy.cfg > /tmp/haproxy.log 2>&1 &
        PROXY_PID=$!
        PROXY_PORT=8080
        ;;
    "openresty"|*)
        echo "[+] Launching OpenResty (nginx)..."
        /usr/local/openresty/bin/openresty -g "daemon off;" &
        PROXY_PID=$!
        PROXY_PORT=8080
        ;;
esac

echo "[+] Proxy process ID: $PROXY_PID"

# Wait for proxy to listen on 8080
echo "[*] Waiting for proxy to accept connections on port $PROXY_PORT..."
PROXY_READY=0
for attempt in {1..60}; do
    if check_port "$PROXY_PORT"; then
        echo "[✓] Proxy listening on port $PROXY_PORT"
        PROXY_READY=1
        break
    fi
    
    if ! kill -0 "$PROXY_PID" 2>/dev/null; then
        echo "[!] ERROR: Proxy process exited unexpectedly!"
        case "$ENGINE" in
            "envoy") tail -30 /tmp/envoy.log 2>/dev/null || echo "No envoy logs" ;;
            "haproxy") tail -30 /tmp/haproxy.log 2>/dev/null || echo "No haproxy logs" ;;
            *) tail -30 /tmp/openresty.log 2>/dev/null || ps aux ;;
        esac
        kill "$XRAY_PID" 2>/dev/null || true
        exit 1
    fi
    
    sleep 0.5
done

if [ $PROXY_READY -eq 0 ]; then
    echo "[!] ERROR: Proxy failed to start listening on port $PROXY_PORT"
    ps aux | grep -E 'xray|nginx|envoy|haproxy' || true
    exit 1
fi

echo "[✓] All services operational and ready"
echo "========================================"
echo "Xray Core:  PID $XRAY_PID"
echo "Proxy:      PID $PROXY_PID ($ENGINE on port $PROXY_PORT)"
echo "========================================"
echo "[*] Container ready for Cloud Run. Monitoring health..."

# ===== KEEP FOREGROUND PROCESS ALIVE FOR CLOUD RUN =====
# This loop keeps the container alive and monitoring both processes
while true; do
    if ! kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "[!] ERROR: Xray process died unexpectedly"
        kill "$PROXY_PID" 2>/dev/null || true
        exit 1
    fi
    
    if ! kill -0 "$PROXY_PID" 2>/dev/null; then
        echo "[!] ERROR: Proxy process died unexpectedly"
        kill "$XRAY_PID" 2>/dev/null || true
        exit 1
    fi
    
    sleep 5
done
