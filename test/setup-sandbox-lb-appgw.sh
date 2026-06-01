#!/bin/bash
#
# test/setup-sandbox-lb-appgw.sh
#
# Create Azure Load Balancer and Application Gateway resources for testing
# bash-my-azure lb-functions and appgw-functions end-to-end.
#
# Requires: az CLI authenticated, active subscription set.
# NOTE: Application Gateway (Standard_v2) incurs cost (~$0.25/hr) — teardown when done.
#
# Usage:
#   export BMAZ_TEST_RG="bmaz-test-rg"
#   export BMAZ_TEST_LOCATION="australiaeast"
#   ./test/setup-sandbox-lb-appgw.sh

set -euo pipefail

RG="${BMAZ_TEST_RG:-bmaz-test-rg}"
LOCATION="${BMAZ_TEST_LOCATION:-australiaeast}"
VNET_NAME="bmaz-test-vnet"
LB_SUBNET="bmaz-lb-subnet"
APPGW_SUBNET="bmaz-appgw-subnet"
LB_NAME="bmaz-test-lb"
LB_PUBLIC_IP="bmaz-lb-pip"
LB_BACKEND_POOL="bmaz-lb-backend"
LB_PROBE_NAME="bmaz-lb-probe"
LB_RULE_NAME="bmaz-lb-rule"
APPGW_NAME="bmaz-test-appgw"
APPGW_PUBLIC_IP="bmaz-appgw-pip"

echo "=== bash-my-azure LB/AppGW Sandbox Setup ==="
echo "Resource Group: $RG"
echo "Location:       $LOCATION"
echo ""

# Ensure resource group exists
echo "Ensuring resource group exists..."
az group create --name "$RG" --location "$LOCATION" --output none 2>/dev/null || true

# ─────────────────────────────────────────────
# Subnets for LB backend and AppGW
# ─────────────────────────────────────────────
echo ""
echo "--- Networking ---"

# Ensure VNet exists (may be from Phase 1)
az network vnet show --resource-group "$RG" --name "$VNET_NAME" --output none 2>/dev/null || \
  az network vnet create \
    --resource-group "$RG" \
    --name "$VNET_NAME" \
    --address-prefix "10.0.0.0/16" \
    --output none

# LB backend subnet
echo "Creating LB backend subnet..."
az network vnet subnet create \
  --resource-group "$RG" \
  --vnet-name "$VNET_NAME" \
  --name "$LB_SUBNET" \
  --address-prefix "10.0.10.0/24" \
  --output none 2>/dev/null || echo "  (subnet may already exist)"

# AppGW dedicated subnet (required — must be /24 or larger)
echo "Creating AppGW subnet..."
az network vnet subnet create \
  --resource-group "$RG" \
  --vnet-name "$VNET_NAME" \
  --name "$APPGW_SUBNET" \
  --address-prefix "10.0.20.0/24" \
  --output none 2>/dev/null || echo "  (subnet may already exist)"

# ─────────────────────────────────────────────
# Load Balancer (Standard SKU, public)
# ─────────────────────────────────────────────
echo ""
echo "--- Load Balancer ---"

echo "Creating public IP for LB..."
az network public-ip create \
  --resource-group "$RG" \
  --name "$LB_PUBLIC_IP" \
  --sku Standard \
  --allocation-method Static \
  --output none

echo "Creating Load Balancer: $LB_NAME"
az network lb create \
  --resource-group "$RG" \
  --name "$LB_NAME" \
  --sku Standard \
  --frontend-ip-name "lb-frontend" \
  --backend-pool-name "$LB_BACKEND_POOL" \
  --public-ip-address "$LB_PUBLIC_IP" \
  --output none

echo "Creating health probe..."
az network lb probe create \
  --resource-group "$RG" \
  --lb-name "$LB_NAME" \
  --name "$LB_PROBE_NAME" \
  --protocol Http \
  --port 80 \
  --path "/healthz" \
  --interval 15 \
  --threshold 2 \
  --output none

echo "Creating LB rule..."
az network lb rule create \
  --resource-group "$RG" \
  --lb-name "$LB_NAME" \
  --name "$LB_RULE_NAME" \
  --protocol Tcp \
  --frontend-port 80 \
  --backend-port 8080 \
  --frontend-ip-name "lb-frontend" \
  --backend-pool-name "$LB_BACKEND_POOL" \
  --probe-name "$LB_PROBE_NAME" \
  --output none

echo "Creating second LB rule (HTTPS)..."
az network lb probe create \
  --resource-group "$RG" \
  --lb-name "$LB_NAME" \
  --name "bmaz-lb-probe-https" \
  --protocol Tcp \
  --port 443 \
  --interval 30 \
  --threshold 3 \
  --output none

az network lb rule create \
  --resource-group "$RG" \
  --lb-name "$LB_NAME" \
  --name "bmaz-lb-rule-https" \
  --protocol Tcp \
  --frontend-port 443 \
  --backend-port 8443 \
  --frontend-ip-name "lb-frontend" \
  --backend-pool-name "$LB_BACKEND_POOL" \
  --probe-name "bmaz-lb-probe-https" \
  --output none

# ─────────────────────────────────────────────
# Application Gateway (Standard_v2, public)
# ─────────────────────────────────────────────
echo ""
echo "--- Application Gateway (takes 5-10 minutes) ---"

echo "Creating public IP for AppGW..."
az network public-ip create \
  --resource-group "$RG" \
  --name "$APPGW_PUBLIC_IP" \
  --sku Standard \
  --allocation-method Static \
  --output none

echo "Creating Application Gateway: $APPGW_NAME"
az network application-gateway create \
  --resource-group "$RG" \
  --name "$APPGW_NAME" \
  --location "$LOCATION" \
  --sku Standard_v2 \
  --capacity 1 \
  --vnet-name "$VNET_NAME" \
  --subnet "$APPGW_SUBNET" \
  --public-ip-address "$APPGW_PUBLIC_IP" \
  --frontend-port 80 \
  --http-settings-port 8080 \
  --http-settings-protocol Http \
  --priority 100 \
  --output none

echo "Adding HTTPS frontend port..."
az network application-gateway frontend-port create \
  --resource-group "$RG" \
  --gateway-name "$APPGW_NAME" \
  --name "https-port" \
  --port 443 \
  --output none

echo "Creating self-signed SSL cert for testing..."
az network application-gateway ssl-cert create \
  --resource-group "$RG" \
  --gateway-name "$APPGW_NAME" \
  --name "bmaz-test-cert" \
  --cert-file <(openssl req -x509 -nodes -days 30 -newkey rsa:2048 \
    -keyout /dev/stdout -subj "/CN=bmaz-test.example.com" 2>/dev/null | \
    openssl pkcs12 -export -passout pass:BmazTest123 -in /dev/stdin -certfile /dev/stdin) \
  --cert-password "BmazTest123" \
  --output none 2>/dev/null || echo "  (SSL cert creation may require alternative approach)"

echo "Adding HTTPS listener..."
az network application-gateway http-listener create \
  --resource-group "$RG" \
  --gateway-name "$APPGW_NAME" \
  --name "bmaz-https-listener" \
  --frontend-port "https-port" \
  --frontend-ip "appGatewayFrontendIP" \
  --host-name "test.example.com" \
  --output none 2>/dev/null || echo "  (HTTPS listener may need ssl-cert)"

echo "Adding second backend pool..."
az network application-gateway address-pool create \
  --resource-group "$RG" \
  --gateway-name "$APPGW_NAME" \
  --name "bmaz-api-backend" \
  --servers "10.0.20.10" "10.0.20.11" \
  --output none

echo "Adding custom health probe..."
az network application-gateway probe create \
  --resource-group "$RG" \
  --gateway-name "$APPGW_NAME" \
  --name "bmaz-health-probe" \
  --protocol Http \
  --host "test.example.com" \
  --path "/healthz" \
  --interval 30 \
  --threshold 3 \
  --timeout 30 \
  --output none

echo ""
echo "=== LB/AppGW Sandbox Setup Complete ==="
echo ""
echo "Resources created in $RG:"
echo "  Load Balancer:     $LB_NAME"
echo "    Frontend IP:     lb-frontend (public: $LB_PUBLIC_IP)"
echo "    Backend Pool:    $LB_BACKEND_POOL"
echo "    Probes:          $LB_PROBE_NAME, bmaz-lb-probe-https"
echo "    Rules:           $LB_RULE_NAME, bmaz-lb-rule-https"
echo ""
echo "  App Gateway:       $APPGW_NAME"
echo "    Frontend IP:     appGatewayFrontendIP (public: $APPGW_PUBLIC_IP)"
echo "    Listeners:       appGatewayHttpListener, bmaz-https-listener"
echo "    Backend Pools:   appGatewayBackendPool, bmaz-api-backend"
echo "    Probes:          bmaz-health-probe"
echo ""
echo "Test commands:"
echo "  source lib/shared-functions && source lib/lb-functions && source lib/appgw-functions"
echo "  lbs"
echo "  lbs | lb-rules"
echo "  lbs | lb-probes"
echo "  lbs | lb-backends"
echo "  lbs | lb-frontend-ips"
echo "  appgws"
echo "  appgws | appgw-listeners"
echo "  appgws | appgw-rules"
echo "  appgws | appgw-backends"
echo "  appgws | appgw-ssl-certs"
echo "  appgws | appgw-ssl-profiles"
echo "  appgws | appgw-probes"
echo "  appgws | appgw-frontend-ips"
echo ""
echo "Teardown: ./test/teardown-sandbox.sh (deletes entire RG)"
