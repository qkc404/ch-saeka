#!/bin/bash

# ANSI Color Codes
CYAN="\e[36m"
YELLOW="\e[33m"
GREEN="\e[32m"
RESET="\e[0m"

echo -e "  ${CYAN}PLEASE SELECT A REGION TO DEPLOY. PLEASE NOTE THAT ONCE SELECTED, THIS CANNOT BE CHANGED.${RESET}"
echo ""
echo -e "  ${YELLOW}1)  us-central1 (Iowa)${RESET}"
echo -e "  ${YELLOW}2)  us-east1 (South Carolina)${RESET}"
echo -e "  ${YELLOW}3)  us-east4 (Northern Virginia)${RESET}"
echo -e "  ${YELLOW}4)  us-west1 (Oregon)${RESET}"
echo -e "  ${YELLOW}5)  asia-east1 (Taiwan)${RESET}"
echo -e "  ${YELLOW}6)  asia-east2 (Hong Kong)${RESET}"
echo -e "  ${YELLOW}7)  asia-northeast1 (Tokyo)${RESET}"
echo -e "  ${YELLOW}8)  asia-southeast1 (Singapore)${RESET}"
echo -e "  ${YELLOW}9)  europe-west1 (Belgium)${RESET}"
echo -e "  ${YELLOW}10) europe-west2 (London)${RESET}"
echo -e "  ${YELLOW}11) europe-west4 (Netherlands)${RESET}"
echo -e "  ${YELLOW}12) southamerica-east1 (São Paulo)${RESET}"
echo ""

read -r -p "$(echo -e "  ${CYAN}CHOICE [1-12]: ${RESET}")" REGION_CHOICE

case "$REGION_CHOICE" in
    1)  REGION="us-central1";;
    2)  REGION="us-east1";;
    3)  REGION="us-east4";;
    4)  REGION="us-west1";;
    5)  REGION="asia-east1";;
    6)  REGION="asia-east2";;
    7)  REGION="asia-northeast1";;
    8)  REGION="asia-southeast1";;
    9)  REGION="europe-west1";;
    10) REGION="europe-west2";;
    11) REGION="europe-west4";;
    12) REGION="southamerica-east1";;
    *) 
       echo -e "  [!] Invalid selection, defaulting to us-central1."
       REGION="us-central1"
       ;;
esac

export REGION
echo ""
echo -e "  ${GREEN}ACTIVE REGION: ${REGION}${RESET}"
echo ""
