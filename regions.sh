#!/bin/bash

# ANSI Color Codes
CYAN="\e[36m"
YELLOW="\e[33m"
GREEN="\e[32m"
RESET="\e[0m"

echo -e "  ${CYAN}PLEASE SELECT A REGION TO DEPLOY. PLEASE NOTE THAT ONCE SELECTED, THIS CANNOT BE CHANGED.${RESET}"
echo ""
echo -e "  ${YELLOW}1) us-central1 (Iowa)${RESET}"
echo -e "  ${YELLOW}2) us-east1 (South Carolina)${RESET}"
echo -e "  ${YELLOW}3) us-west1 (Oregon)${RESET}"
echo -e "  ${YELLOW}4) asia-east1 (Taiwan)${RESET}"
echo -e "  ${YELLOW}5) asia-southeast1 (Singapore)${RESET}"
echo -e "  ${YELLOW}6) europe-west1 (Belgium)${RESET}"
echo -e "  ${YELLOW}7) europe-west4 (Netherlands)${RESET}"
echo ""

read -r -p "$(echo -e "  ${CYAN}CHOICE [1-7]: ${RESET}")" REGION_CHOICE

case "$REGION_CHOICE" in
    1) REGION="us-central1";;
    2) REGION="us-east1";;
    3) REGION="us-west1";;
    4) REGION="asia-east1";;
    5) REGION="asia-southeast1";;
    6) REGION="europe-west1";;
    7) REGION="europe-west4";;
    *) 
       echo -e "  [!] Invalid selection, defaulting to us-central1."
       REGION="us-central1"
       ;;
esac

export REGION
echo ""
echo -e "  ${GREEN}ACTIVE REGION: ${REGION}${RESET}"
echo ""
