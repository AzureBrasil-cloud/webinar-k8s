#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get service URL
SERVICE_URL=$(minikube service myapp-webapi-nodeport -n webinar4 --url)

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Load Balancing${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Service URL: ${SERVICE_URL}${NC}\n"

# Test /instance endpoint multiple times
echo -e "${GREEN}Testing /instance endpoint (10 requests):${NC}\n"

for i in {1..10}; do
  echo -e "${YELLOW}Request #${i}:${NC}"
  curl -s "${SERVICE_URL}/instance" | jq '.'
  echo ""
  sleep 0.5
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "You should see different InstanceId and Hostname values,"
echo -e "proving that the Service is load balancing across pods!"
echo -e "${BLUE}========================================${NC}"

