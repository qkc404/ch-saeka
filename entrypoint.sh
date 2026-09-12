#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[+]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[!]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[*]${NC} $1"
}

# ============================================================================
# 1. GENERATE SSH HOST KEYS
# ============================================================================
log_info "Generating SSH Host Keys..."
ssh-keygen -A
RUN mkdir -p /var/run/sshd
RUN mkdir -p /var/log/xray
log_success "SSH Host Keys generated"

# ============================================================================
# 2. GENERATE SELF-SIGNED CERTIFICATES FOR XRAY TLS
# ============================================================================
log_info "Generating Self-Signed TLS Certificates for XRAY..."
mkdir -p /etc/xray/certs

if [ ! -f /etc/xray/certs/cert.pem ] || [ ! -f /etc/xray/certs/key.pem ]; then
    openssl req -x509 -newkey rsa:4096 -keyout /etc/xray/certs/key.pem \
        -out /etc/xray/certs/cert.pem -days 365 -nodes \
        -subj "/C=SG/ST=Gaming/L=Cloud/O=Saeka/CN=saeka-gaming.local" \
        2>/dev/null
    log_success "TLS Certificates generated"
else
    log_warn "TLS Certificates already exist"
fi

# ============================================================================
# 3. START SSH DAEMON (Port 22)
# ============================================================================
log_info "Starting SSH Daemon (Port 22)..."
/usr/sbin/sshd -D &
SSH_PID=$!
log_success "SSH Daemon started (PID: $SSH_PID)"

# ============================================================================
# 4. START BADVPN UDPGW (UDP Gaming Gateway - Port 7300)
# ============================================================================
log_info "Starting BadVPN UDPGW (UDP Gaming Gateway)..."
badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500 --max-connections 500 &
UDPGW_PID=$!
log_success "BadVPN UDPGW started (PID: $UDPGW_PID)"

# ============================================================================
# 5. START XRAY CORE (VLESS + Trojan + Shadowsocks - Ports 10086-10087)
# ============================================================================
log_info "Starting XRAY Core (VLESS/Trojan/Shadowsocks)..."

# Validate XRAY config
if /usr/local/bin/xray run -test -config /etc/xray/config.json 2>/dev/null; then
    log_success "XRAY config validation passed"
else
    log_error "XRAY config validation failed!"
    exit 1
fi

/usr/local/bin/xray run -config /etc/xray/config.json &
XRAY_PID=$!
log_success "XRAY Core started (PID: $XRAY_PID)"

sleep 2

# ============================================================================
# 6. CREATE WEBSOCKET-TO-TCP BRIDGE FOR WS TUNNELING
# ============================================================================
log_info "Creating WebSocket-to-TCP Bridge (Port 2222)..."
cat << 'PYEOF' > /tmp/bridge.py
#!/usr/bin/env python3
import socket
import threading
import sys
import time

def bridge(src, dst, name):
    try:
        while True:
            data = src.recv(8192)
            if not data:
                break
            dst.sendall(data)
    except Exception as e:
        pass
    finally:
        try:
            src.close()
            dst.close()
        except:
            pass

def handle_client(client, addr):
    try:
        # Receive WebSocket handshake
        req = client.recv(4096)
        if not req:
            return
        
        # Send WebSocket upgrade response
        response = (
            b"HTTP/1.1 101 Switching Protocols\r\n"
            b"Upgrade: websocket\r\n"
            b"Connection: Upgrade\r\n"
            b"Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n"
            b"Sec-WebSocket-Version: 13\r\n"
            b"\r\n"
        )
        client.sendall(response)
        
        # Connect to SSH
        ssh = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh.connect(('127.0.0.1', 22))
        
        # Bridge traffic bidirectionally
        t1 = threading.Thread(target=bridge, args=(client, ssh, "client->ssh"), daemon=True)
        t2 = threading.Thread(target=bridge, args=(ssh, client, "ssh->client"), daemon=True)
        t1.start()
        t2.start()
        
    except Exception as e:
        try:
            client.close()
        except:
            pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', 2222))
    server.listen(100)
    print("[+] WebSocket Bridge listening on 127.0.0.1:2222")
    
    try:
        while True:
            client, addr = server.accept()
            threading.Thread(target=handle_client, args=(client, addr), daemon=True).start()
    except KeyboardInterrupt:
        server.close()
        print("\n[*] Bridge stopped")
        sys.exit(0)

if __name__ == "__main__":
    main()
PYEOF

chmod +x /tmp/bridge.py
python3 /tmp/bridge.py &
BRIDGE_PID=$!
log_success "WebSocket Bridge started (PID: $BRIDGE_PID)"

# ============================================================================
# 7. START NGINX WITH PROXY CONFIGURATION (Port 8080)
# ============================================================================
log_info "Starting Nginx (Port 8080)..."
nginx -g "daemon off;" &
NGINX_PID=$!
sleep 2
log_success "Nginx started (PID: $NGINX_PID)"

# ============================================================================
# 8. DISPLAY CONNECTION INFORMATION
# ============================================================================
SERVICE_URL=${SERVICE_URL:-"http://localhost:8080"}
CLEAN_HOST=$(echo "$SERVICE_URL" | sed 's|https://||; s|http://||')

clear
cat << "EOF"

╔════════════════════════════════════════════════════════════════════════════╗
║                   🎮 SAEKA GCP GAMING GATEWAY 🎮                          ║
║                        Multi-Protocol SSH/XRAY                             ║
╚════════════════════════════════════════════════════════════════════════════╝

EOF

echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           ✓ ALL SERVICES DEPLOYED & RUNNING${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${BLUE}[1] SSH DIRECT CONNECTION${NC}"
echo -e "    Host:       ${CLEAN_HOST}"
echo -e "    Port:       22"
echo -e "    Username:   saeka"
echo -e "    Password:   saeka"
echo -e "    Protocol:   SSH (Port Forwarding + Tunnel Support)\n"

echo -e "${BLUE}[2] XRAY VLESS PROTOCOL${NC}"
echo -e "    Address:    ${CLEAN_HOST}"
echo -e "    Port:       10086"
echo -e "    Protocol:   VLESS + XTLS"
echo -e "    UUID:       chsaeka-vless-uuid-gaming-001"
echo -e "    Flow:       xtls-rprx-vision"
echo -e "    TLS:        Enabled (Self-Signed)\n"

echo -e "${BLUE}[3] XRAY TROJAN PROTOCOL${NC}"
echo -e "    Address:    ${CLEAN_HOST}"
echo -e "    Port:       10087"
echo -e "    Protocol:   Trojan + TLS"
echo -e "    Password:   chsaeka-trojan-password-gaming-001"
echo -e "    TLS:        Enabled (Self-Signed)\n"

echo -e "${BLUE}[4] SHADOWSOCKS PROTOCOL${NC}"
echo -e "    Address:    ${CLEAN_HOST}"
echo -e "    Port:       2222 (via WebSocket Bridge)"
echo -e "    Method:     chacha20-poly1305"
echo -e "    Password:   chsaeka-shadowsocks-gaming\n"

echo -e "${BLUE}[5] WEBSOCKET TUNNEL${NC}"
echo -e "    Endpoint:   http://${CLEAN_HOST}:8080/saeka-ssh"
echo -e "    Backend:    SSH @ 127.0.0.1:22"
echo -e "    Port:       8080\n"

echo -e "${BLUE}[6] UDP GAMING SUPPORT${NC}"
echo -e "    Gateway:    BadVPN UDPGW"
echo -e "    Port:       7300 (Internal)"
echo -e "    Max Clients: 500\n"

echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}ACTIVE SERVICES:${NC}"
echo -e "  • SSH Daemon (PID: $SSH_PID)"
echo -e "  • BadVPN UDPGW (PID: $UDPGW_PID)"
echo -e "  • XRAY Core (PID: $XRAY_PID)"
echo -e "  • WebSocket Bridge (PID: $BRIDGE_PID)"
echo -e "  • Nginx Proxy (PID: $NGINX_PID)"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}\n"

# ============================================================================
# 9. GRACEFUL SHUTDOWN HANDLER
# ============================================================================
cleanup() {
    log_warn "Shutdown signal received..."
    kill $SSH_PID $UDPGW_PID $XRAY_PID $BRIDGE_PID $NGINX_PID 2>/dev/null || true
    log_success "All services stopped"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Keep container running
wait $NGINX_PID
