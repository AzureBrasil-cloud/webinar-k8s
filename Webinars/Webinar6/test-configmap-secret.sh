#!/bin/bash
# Test script for Webinar 6 - ConfigMaps & Secrets
# Demonstrates:
#  - discount applied via ConfigMap env var
#  - ConfigMap changes require a rollout restart to take effect
#  - nullable discount falling back to 0% when the key is removed
#  - Secret is base64-encoded (not encrypted) at rest

set -e

NAMESPACE="webinar6"

echo "=== 1) Port-forward myapp-webapi-service ==="
kubectl port-forward svc/myapp-webapi-service 8080:80 -n "$NAMESPACE" >/tmp/webinar6-webapi-pf.log 2>&1 &
WEBAPI_PF_PID=$!
sleep 3

echo ""
echo "=== 2) Current products (discount from ConfigMap) ==="
curl -s http://localhost:8080/api/products | jq .

echo ""
echo "=== 3) Updating ConfigMap discount to 20% ==="
kubectl patch configmap myapp-webapi-config -n "$NAMESPACE" --type merge -p '{"data":{"Discount__Percentage":"20"}}'

echo ""
echo "=== 4) Restarting deployment to pick up the new ConfigMap value ==="
kubectl rollout restart deployment/myapp-webapi -n "$NAMESPACE"
kubectl rollout status deployment/myapp-webapi -n "$NAMESPACE"

echo ""
echo "=== 5) Products after restart (expect 20% discount) ==="
curl -s http://localhost:8080/api/products | jq .

echo ""
echo "=== 6) Removing Discount__Percentage key (fallback to 0%) ==="
kubectl patch configmap myapp-webapi-config -n "$NAMESPACE" --type json -p '[{"op":"remove","path":"/data/Discount__Percentage"}]'
kubectl rollout restart deployment/myapp-webapi -n "$NAMESPACE"
kubectl rollout status deployment/myapp-webapi -n "$NAMESPACE"

echo ""
echo "=== 7) Products with no discount configured (expect 0%) ==="
curl -s http://localhost:8080/api/products | jq .

echo ""
echo "=== 8) Inspecting the Secret (base64, not encrypted) ==="
kubectl get secret myapp-webapp-secret -n "$NAMESPACE" -o yaml
echo "Decoded value:"
kubectl get secret myapp-webapp-secret -n "$NAMESPACE" -o jsonpath='{.data.ApiSettings__WebApiUrl}' | base64 --decode
echo ""

kill "$WEBAPI_PF_PID" 2>/dev/null || true

echo ""
echo "Done. Restore the original ConfigMap with: kubectl apply -f configmap.yaml -n $NAMESPACE"
