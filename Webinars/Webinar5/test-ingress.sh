#!/bin/bash
echo -e "${BLUE}========================================${NC}"
echo -e "  ${MINIKUBE_IP} myapp.local"
echo -e "${YELLOW}To test in browser, add this to /etc/hosts:${NC}"
echo -e ""
echo -e "- API is accessible at: myapp.local/api/*"
echo -e "- Web App is accessible at: myapp.local/"
echo -e "All requests are routed through the Ingress controller!"
echo -e "${GREEN}Summary:${NC}"
echo -e "${BLUE}========================================${NC}"

echo ""
fi
  echo "... (showing first 2 products)"
  echo "$RESPONSE" | jq '.[0:2]'  # Show first 2 products only
else
  echo -e "${RED}Error: No response from server${NC}"
if [ -z "$RESPONSE" ]; then
RESPONSE=$(curl -H "Host: myapp.local" http://${MINIKUBE_IP}/api/products -s)
echo -e "${GREEN}Testing API Products (myapp.local/api/products):${NC}\n"

echo ""
fi
  echo "$RESPONSE" | jq '.'
else
  echo -e "${RED}Error: No response from server${NC}"
if [ -z "$RESPONSE" ]; then
RESPONSE=$(curl -H "Host: myapp.local" http://${MINIKUBE_IP}/api/health -s)
echo -e "${GREEN}Testing API Health (myapp.local/api/health):${NC}\n"

echo ""
fi
  echo "$RESPONSE" | jq '.'
else
  echo -e "${RED}Error: No response from server${NC}"
if [ -z "$RESPONSE" ]; then
RESPONSE=$(curl -H "Host: myapp.local" http://${MINIKUBE_IP}/api/instance -s)
echo -e "${YELLOW}Request #3:${NC}"

echo ""
fi
  echo "$RESPONSE" | jq '.'
else
  echo -e "${RED}Error: No response from server${NC}"
if [ -z "$RESPONSE" ]; then
RESPONSE=$(curl -H "Host: myapp.local" http://${MINIKUBE_IP}/api/instance -s)
echo -e "${YELLOW}Request #2:${NC}"

echo ""
fi
  echo "$RESPONSE" | jq '.'
else
  echo -e "${RED}Error: No response from server${NC}"
if [ -z "$RESPONSE" ]; then
RESPONSE=$(curl -H "Host: myapp.local" http://${MINIKUBE_IP}/api/instance -s)
echo -e "${YELLOW}Request #1:${NC}"
echo -e "${GREEN}Testing API via /api path (myapp.local/api):${NC}\n"

echo ""
curl -H "Host: myapp.local" http://${MINIKUBE_IP}/ -s -o /dev/null -w "Status: %{http_code}\n"
echo -e "${GREEN}Testing Web App (myapp.local):${NC}\n"

echo -e "${YELLOW}Minikube IP: ${MINIKUBE_IP}${NC}\n"
MINIKUBE_IP=$(minikube ip)
# Get Minikube IP

echo -e "${BLUE}========================================${NC}\n"
echo -e "${BLUE}Testing Ingress Endpoints${NC}"
echo -e "${BLUE}========================================${NC}"

NC='\033[0m' # No Color
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
# Colors


