#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Host-Based Ingress Routing${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
echo -e "${YELLOW}Minikube IP: ${MINIKUBE_IP}${NC}\n"

echo -e "${GREEN}Testing Web App (myapp.local):${NC}\n"
curl -H "Host: myapp.local" http://${MINIKUBE_IP}/ -s -o /dev/null -w "Status: %{http_code}\n"
echo ""

echo -e "${GREEN}Testing API (api.myapp.local):${NC}\n"
echo -e "${YELLOW}Instance endpoint:${NC}"
RESPONSE=$(curl -H "Host: api.myapp.local" http://${MINIKUBE_IP}/instance -s)
if [ -z "$RESPONSE" ]; then
  echo -e "${RED}Error: No response from server${NC}"
else
  echo "$RESPONSE" | jq '.'
fi
echo ""

echo -e "${YELLOW}Health endpoint:${NC}"
RESPONSE=$(curl -H "Host: api.myapp.local" http://${MINIKUBE_IP}/health -s)
if [ -z "$RESPONSE" ]; then
  echo -e "${RED}Error: No response from server${NC}"
else
  echo "$RESPONSE" | jq '.'
fi
echo ""

echo -e "${YELLOW}Products endpoint:${NC}"
RESPONSE=$(curl -H "Host: api.myapp.local" http://${MINIKUBE_IP}/products -s)
if [ -z "$RESPONSE" ]; then
  echo -e "${RED}Error: No response from server${NC}"
else
  echo "$RESPONSE" | jq '.[0:2]'  # Show first 2 products only
  echo "... (showing first 2 products)"
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "Different hosts route to different services!"
echo -e "- myapp.local → Web App"
echo -e "- api.myapp.local → API"
echo -e ""
echo -e "${YELLOW}To test in browser, add these to /etc/hosts:${NC}"
echo -e "  ${MINIKUBE_IP} myapp.local"
echo -e "  ${MINIKUBE_IP} api.myapp.local"
echo -e "${BLUE}========================================${NC}"

