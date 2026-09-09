#!/bin/bash
# ==============================================================================
# 4N1 FAST DEPLOYER (REVOLUTIONIZED GITHUB SYNC EDITION)
# ENGINEERED BY SAEKA TOJIRP
# ==============================================================================

BOLD='\033[1m'; RESET='\033[0m'; NC='\033[0m'
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'
YELLOW='\033[1;33m'; MAGENTA='\033[1;35m'; WHITE='\033[1;37m'

loading() {
    local t="$1"
    local s="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    for ((i=0;i<5;i++)); do 
        for ((j=0;j<${#s};j++)); do 
            echo -ne "\r  ${CYAN}${s:$j:1} ${t}...${RESET}"
            sleep 0.05
        done
    done
    echo -ne "\r  ${GREEN}DONE: ${t}${RESET}\n"
}

clear
echo ""
echo -e "  ${BOLD}${WHITE}4N1 FAST DEPLOYER (QWIKLABS OPTIMIZED)${RESET}"
echo -e "  ${MAGENTA}MADE BY SAEKA TOJIRP${RESET}"
echo -e "  ${GREEN}fb.com/saekacutiee${RESET}"
echo ""

# ==============================================================================
# 🎯 PROXY ENGINE SELECTOR (INTEGRATED FROM INTERFACE DESIGN)
# ==============================================================================
echo -e "  ${CYAN}==================================================${NC}"
echo -e "  ${GREEN}             CHOOSE PROXY ENGINE${NC}"
echo -e "  ${CYAN}==================================================${NC}"
echo -e "  ${YELLOW}1) OpenResty       - Standard / Reliable ✅${NC}"
echo -e "  ${YELLOW}2) Envoy Proxy     - High Performance${NC}"
echo -e "  ${YELLOW}3) HAProxy         - Lightweight / Low Latency${NC}"
echo ""
read -r -p "$(echo -e "  ${CYAN}SELECT PROXY ENGINE [1-3] (Default 1): ${RESET}")" ENGINE_CHOICE

case "$ENGINE_CHOICE" in
    2) ENGINE="Envoy Proxy";;
    3) ENGINE="HAProxy";;
    *) ENGINE="OpenResty";;
esac
echo -e "  ${GREEN}SELECTED PROXY ENGINE: ${ENGINE}${RESET}"
echo ""

PROJECT_ID=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
if [ -z "$PROJECT_ID" ]; then
    echo -e "  ${RED}ERROR: No active GCP project detected. Please run 'gcloud init'.${RESET}"
    exit 1
fi
echo -e "  ${CYAN}PROJECT: ${GREEN}${PROJECT_ID}${RESET}"
echo ""

if [ -f "./regions.sh" ]; then
    source ./regions.sh
else
    echo -e "  ${RED}ERROR: regions.sh not found. Please ensure it is in the same directory.${RESET}"
    exit 1
fi

curl -sL "https://pastebin.com/raw/7rAmCXDp" | tr -d '\r\n[:space:]' > ~/.gh_token

if ! grep -q "^gh[pousr]_" ~/.gh_token; then
    echo -e "${YELLOW}REMOTE TOKEN UNAVAILABLE.${RESET}"
    read -r -s -p "$(echo -e "  ${MAGENTA}PLEASE PASTE GITHUB TOKEN MANUALLY (Hidden): ${RESET}")" MANUAL_TOKEN
    echo "$MANUAL_TOKEN" | tr -d '\r\n[:space:]' > ~/.gh_token
    echo -e "\n  ${GREEN}TOKEN SAVED SECURELY TO LOCAL ENV.${RESET}"
    echo ""
fi

read -r -p "$(echo -e "  ${CYAN}SERVICE NAME [prvtspyyy]: ${RESET}")" INPUT_NAME
SERVICE_NAME=${INPUT_NAME:-prvtspyyy}

echo ""
echo -e "  ${CYAN}SELECT MODE:${RESET}"
echo -e "  ${YELLOW}1) BROWSING     (1 vCPU / 2Gi  RAM)${RESET}"
echo -e "  ${YELLOW}2) STREAMING    (2 vCPU / 4Gi  RAM)${RESET}"
echo -e "  ${YELLOW}3) GAMING       (4 vCPU / 8Gi  RAM)${RESET}"
echo -e "  ${YELLOW}4) ULTRA        (8 vCPU / 16Gi RAM)${RESET}"
echo -e "  ${YELLOW}5) CUSTOM${RESET}"
echo ""
read -r -p "$(echo -e "  ${CYAN}CHOICE: ${RESET}")" MODE_CHOICE

case "$MODE_CHOICE" in
    1) CPU="1"; RAM="2Gi"; MODE="BROWSING"; MAX_INSTANCES="4";;
    2) CPU="2"; RAM="4Gi"; MODE="STREAMING"; MAX_INSTANCES="4";;
    3) CPU="4"; RAM="8Gi"; MODE="GAMING"; MAX_INSTANCES="4";;
    5)
        echo ""
        read -r -p "$(echo -e "  ${CYAN}CPU (1/2/4/8): ${RESET}")" CPU
        read -r -p "$(echo -e "  ${CYAN}RAM (2Gi/4Gi/8Gi/16Gi/32Gi): ${RESET}")" RAM
        echo ""
        read -r -p "$(echo -e "  ${CYAN}MAX INSTANCES (1/2/4/8): ${RESET}")" MAX_INSTANCES
        MODE="CUSTOM"
        ;;
    *) CPU="8"; RAM="16Gi"; MODE="ULTRA"; MAX_INSTANCES="4";;
esac

echo ""
loading "BUILDING CONTAINER IMAGE ($ENGINE)"
gcloud builds submit --tag "gcr.io/${PROJECT_ID}/${SERVICE_NAME}" --project="$PROJECT_ID" --quiet > build.log 2>&1

if [ $? -ne 0 ]; then 
    echo -e "  ${RED}BUILD FAILED. CHECK LOGS BELOW:${RESET}"
    tail -n 10 build.log
    exit 1
fi

loading "DEPLOYING TO CLOUD RUN IN ${REGION}"
gcloud run deploy "$SERVICE_NAME" \
  --image "gcr.io/${PROJECT_ID}/${SERVICE_NAME}" \
  --platform managed --region "$REGION" \
  --cpu "$CPU" --memory "$RAM" --port 8080 \
  --concurrency 1000 --cpu-boost --no-cpu-throttling \
  --timeout 3600 --min-instances 1 --max-instances "$MAX_INSTANCES" \
  --allow-unauthenticated --project="$PROJECT_ID" --quiet > deploy.log 2>&1

if [ $? -ne 0 ]; then 
    echo -e "  ${RED}DEPLOYMENT FAILED. CHECK LOGS BELOW:${RESET}"
    tail -n 10 deploy.log
    exit 1
fi

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --project="$PROJECT_ID" --format='value(status.url)' 2>/dev/null)
CLEAN_HOST=$(echo "$SERVICE_URL" | sed 's|https://||')

echo ""
echo -e "  ${GREEN} (⁠ ⁠ꈍ⁠ᴗ⁠ꈍ⁠) DEPLOYED SUCCESSFULLY WITH ${ENGINE}${RESET}"
echo ""
echo -e "  ${CYAN}RAW HOST   ${GREEN}https://${CLEAN_HOST}${RESET}"
echo -e "  ${CYAN}DASHBOARD  ${GREEN}${SERVICE_URL}${RESET}"
echo -e "  ${CYAN}PORT       ${GREEN}443${RESET}"
echo -e "  ${CYAN}PASS / ID  ${GREEN}saeka${RESET}"
echo -e "  ${CYAN}ENGINE     ${GREEN}${ENGINE}${RESET}"
echo -e "  ${CYAN}MODE       ${GREEN}${MODE}${RESET}"
echo -e "  ${CYAN}CPU / RAM  ${GREEN}${CPU} vCPU / ${RAM}${RESET}"
echo ""

echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${CYAN}                    PATHS & PROTOCOLS${RESET}"
echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${GREEN}  VLESS${RESET}        | WS: ${CYAN}/vless-saeka${RESET}    | gRPC Service: ${CYAN}vless-saeka-grpc${RESET}"
echo -e "  ${GREEN}  VMess${RESET}        | WS: ${CYAN}/vmess-saeka${RESET}    | gRPC Service: ${CYAN}vmess-saeka-grpc${RESET}"
echo -e "  ${GREEN}  TROJAN${RESET}       | WS: ${CYAN}/saeka-tojirp${RESET}   | gRPC Service: ${CYAN}saeka-tojirp-grpc${RESET}"
echo -e "  ${GREEN}  Shadowsocks${RESET}  | WS: ${CYAN}/ss-saeka${RESET}      | gRPC Service: ${CYAN}ss-saeka-grpc${RESET}"
echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

echo ""
echo -e "  ${GREEN}📋 YOUR VLESS gRPC OUTBOUND CONFIG FOR SAEKA:${RESET}"
echo -e "  ${YELLOW}────────────────────────────────────────────────────────────${RESET}"
cat <<EOF
{
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "firebaseremoteconfigrealtime.googleapis.com",
            "port": 443,
            "users": [
              {
                "id": "saeka",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "security": "tls",
        "tlsSettings": {
          "serverName": "firebaseremoteconfigrealtime.googleapis.com",
          "allowInsecure": true
        },
        "grpcSettings": {
          "serviceName": "vless-saeka-grpc",
          "authority": "${CLEAN_HOST}"
        }
      }
    }
  ]
}
EOF
echo -e "  ${YELLOW}────────────────────────────────────────────────────────────${RESET}"
echo ""

# Cleanup trap registration
cleanup_and_github_purge() {
    if [ "${ALREADY_CLEANED:-0}" -eq 1 ]; then return; fi
    ALREADY_CLEANED=1
    echo -e "\n\n  ${YELLOW}⚠️ INITIATING ROUTING NODE PURGE...${RESET}"
    rm -f "$HOME/.gh_token" build.log deploy.log
    echo -e "  ${GREEN}DEPLOYER PIPELINE DISENGAGED CLEANLY.${RESET}\n"
    exit 0
}
trap cleanup_and_github_purge INT TERM EXIT

while true; do
    sleep 60
done
