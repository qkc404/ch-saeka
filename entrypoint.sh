#!/bin/bash
set -euo pipefail

# =========================================
# ENTRYPOINT - XRAY + OPENRESTY ORCHESTRATION
# Enhanced for stability, low-latency, zero-dropout
# =========================================

trap 'handle_signal' SIGTERM SIGINT

handle_signal() {
    echo "[!] Received shutdown signal. Terminating processes..."
    kill "$XRAY_PID" 2>/dev/null || true
    kill "$PROXY_PID" 2>/dev/null || true
    wait 2>/dev/null || true
    exit 0
}

# ===== XRAY STARTUP =====
echo "[+] Initializing Xray Core..."
xray run -config /etc/xray/config.json > /tmp/xray.log 2>&1 &
XRAY_PID=$!
echo "[+] Xray process ID: $XRAY_PID"

# Wait for Xray to bind on all inbound ports (15 sec timeout)
echo "[*] Waiting for Xray inbound sockets to bind..."
XRAY_PORTS=(10000 10001 10002 10003 10004 10005 10006 10007 10008 10009 10010 10011 10012 10013 10014 10015)
READY=0

for attempt in {1..30}; do
    PORTS_READY=0
    for PORT in "${XRAY_PORTS[@]}"; do
        if nc -z 127.0.0.1 "$PORT" 2>/dev/null; then
            ((PORTS_READY++))
        fi
    done
    
    if [ "$PORTS_READY" -ge 12 ]; then
        READY=1
        echo "[✓] Xray ready on $PORTS_READY core ports (timeout in $(((30-attempt)*0.5))s)"
        break
    fi
    
    if ! kill -0 "$XRAY_PID" 2>/dev/null; then
        echo "[!] ERROR: Xray process exited unexpectedly!"
        cat /tmp/xray.log
        exit 1
    fi
    
    sleep 0.5
done

if [ $READY -eq 0 ]; then
    echo "[!] WARNING: Xray startup timeout (${#XRAY_PORTS[@]} ports not all ready)"
    echo "[!] Last port check: $PORTS_READY / ${#XRAY_PORTS[@]} ready"
    cat /tmp/xray.log | tail -20
fi

echo "[✓] Xray Core fully operational"

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
        /usr/local/openresty/bin/openresty -g "daemon off;" > /tmp/openresty.log 2>&1 &
        PROXY_PID=$!
        PROXY_PORT=8080
        ;;
esac

echo "[+] Proxy process ID: $PROXY_PID"

# Wait for proxy to listen on 8080 (max 15 sec)
echo "[*] Waiting for proxy to accept connections on port $PROXY_PORT..."
for attempt in {1..30}; do
    if nc -z 127.0.0.1 "$PROXY_PORT" 2>/dev/null; then
        echo "[✓] Proxy listening on port $PROXY_PORT"
        break
    fi
    
    if ! kill -0 "$PROXY_PID" 2>/dev/null; then
        echo "[!] ERROR: Proxy process exited unexpectedly!"
        case "$ENGINE" in
            "envoy") cat /tmp/envoy.log ;;
            "haproxy") cat /tmp/haproxy.log ;;
            *) cat /tmp/openresty.log ;;
        esac
        exit 1
    fi
    
    sleep 0.5
done

echo "[✓] All services operational and ready to accept traffic"
echo "========================================"
echo "Xray Core:  PID $XRAY_PID (listening on 16 inbound ports)"
echo "Proxy:      PID $PROXY_PID ($ENGINE listening on $PROXY_PORT)"
echo "========================================"

# ===== PROCESS MONITORING =====
echo "[*] Entering monitoring loop. Press Ctrl+C to shutdown."

wait -n "$XRAY_PID" "$PROXY_PID"
EXIT_CODE=$?

echo "[!] A child process exited with code $EXIT_CODE"
echo "[*] Initiating graceful shutdown..."

kill "$XRAY_PID" 2>/dev/null || true
kill "$PROXY_PID" 2>/dev/null || true

# Grace period for clean shutdown
sleep 2

wait 2>/dev/null || true
echo "[✓] Container shutdown complete"
exit "$EXIT_CODE"
