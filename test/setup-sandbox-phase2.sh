#!/bin/bash
#
# test/setup-sandbox-phase2.sh
#
# Create Azure resources for testing Phase 2 bash-my-azure functions.
# Tests: deployment-functions, keyvault-functions, secret-functions,
#        db-functions, rbac-functions, ad-functions
#
# Requires: az CLI authenticated, active subscription set.
# NOTE: Some resources (Key Vault, SQL) incur cost — teardown when done.
#
# Usage:
#   export BMAZ_TEST_RG="bmaz-test-rg"
#   export BMAZ_TEST_LOCATION="australiaeast"
#   ./test/setup-sandbox-phase2.sh

set -euo pipefail

RG="${BMAZ_TEST_RG:-bmaz-test-rg}"
LOCATION="${BMAZ_TEST_LOCATION:-australiaeast}"
KEYVAULT_NAME="bmaz-kv-$$"
SQL_SERVER_NAME="bmaz-sql-$$"
SQL_ADMIN="sqladmin"
SQL_PASSWORD="BmazT3st!$(openssl rand -hex 4)"
PG_SERVER_NAME="bmaz-pg-$$"
PG_ADMIN="pgadmin"
PG_PASSWORD="BmazPg!$(openssl rand -hex 4)"
DEPLOYMENT_TEMPLATE="/tmp/bmaz-test-template.json"

echo "=== bash-my-azure Phase 2 Sandbox Setup ==="
echo "Resource Group: $RG"
echo "Location:       $LOCATION"
echo ""

# Ensure resource group exists (may already exist from Phase 1)
echo "Ensuring resource group exists..."
az group create --name "$RG" --location "$LOCATION" --output none 2>/dev/null || true

# ─────────────────────────────────────────────
# Key Vault + Secrets
# ─────────────────────────────────────────────
echo ""
echo "--- Key Vault ---"
echo "Creating Key Vault: $KEYVAULT_NAME"
az keyvault create \
  --resource-group "$RG" \
  --name "$KEYVAULT_NAME" \
  --location "$LOCATION" \
  --sku standard \
  --enable-rbac-authorization false \
  --output none

echo "Adding test secrets..."
az keyvault secret set \
  --vault-name "$KEYVAULT_NAME" \
  --name "test-api-key" \
  --value "sk-test-12345-not-real" \
  --output none

az keyvault secret set \
  --vault-name "$KEYVAULT_NAME" \
  --name "test-db-password" \
  --value "TestDbP@ss123" \
  --expires "2026-12-31T00:00:00Z" \
  --output none

az keyvault secret set \
  --vault-name "$KEYVAULT_NAME" \
  --name "test-cert-pass" \
  --value "CertP@ss456" \
  --expires "2026-08-15T00:00:00Z" \
  --output none

echo "Adding test key..."
az keyvault key create \
  --vault-name "$KEYVAULT_NAME" \
  --name "test-encryption-key" \
  --kty RSA \
  --size 2048 \
  --output none

# ─────────────────────────────────────────────
# ARM Deployment (simple storage account)
# ─────────────────────────────────────────────
echo ""
echo "--- ARM Deployment ---"

# Create a minimal ARM template
cat > "$DEPLOYMENT_TEMPLATE" << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "storagePrefix": {
      "type": "string",
      "defaultValue": "bmazp2"
    }
  },
  "variables": {
    "storageName": "[concat(parameters('storagePrefix'), uniqueString(resourceGroup().id))]"
  },
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2023-01-01",
      "name": "[variables('storageName')]",
      "location": "[resourceGroup().location]",
      "sku": { "name": "Standard_LRS" },
      "kind": "StorageV2"
    }
  ],
  "outputs": {
    "storageAccountName": {
      "type": "string",
      "value": "[variables('storageName')]"
    },
    "storageEndpoint": {
      "type": "string",
      "value": "[reference(variables('storageName')).primaryEndpoints.blob]"
    }
  }
}
EOF

echo "Deploying ARM template: bmaz-test-deploy..."
az deployment group create \
  --resource-group "$RG" \
  --name "bmaz-test-deploy" \
  --template-file "$DEPLOYMENT_TEMPLATE" \
  --parameters storagePrefix="bmazp2" \
  --output none

rm -f "$DEPLOYMENT_TEMPLATE"

# ─────────────────────────────────────────────
# Azure SQL Server + Database
# ─────────────────────────────────────────────
echo ""
echo "--- Azure SQL ---"
echo "Creating SQL Server: $SQL_SERVER_NAME (this takes a moment)..."
az sql server create \
  --resource-group "$RG" \
  --name "$SQL_SERVER_NAME" \
  --location "$LOCATION" \
  --admin-user "$SQL_ADMIN" \
  --admin-password "$SQL_PASSWORD" \
  --output none

echo "Creating test database..."
az sql db create \
  --resource-group "$RG" \
  --server "$SQL_SERVER_NAME" \
  --name "bmaz-test-db" \
  --edition "Basic" \
  --output none

# ─────────────────────────────────────────────
# PostgreSQL Flexible Server (Burstable B1ms — cheapest)
# ─────────────────────────────────────────────
echo ""
echo "--- PostgreSQL Flexible Server ---"
echo "Creating PG server: $PG_SERVER_NAME (this takes 2-3 minutes)..."
az postgres flexible-server create \
  --resource-group "$RG" \
  --name "$PG_SERVER_NAME" \
  --location "$LOCATION" \
  --admin-user "$PG_ADMIN" \
  --admin-password "$PG_PASSWORD" \
  --sku-name "Standard_B1ms" \
  --tier "Burstable" \
  --storage-size 32 \
  --version "16" \
  --yes \
  --output none

echo "Creating test database..."
az postgres flexible-server db create \
  --resource-group "$RG" \
  --server-name "$PG_SERVER_NAME" \
  --database-name "bmaz-test-db" \
  --output none

# ─────────────────────────────────────────────
# RBAC — Create a test role assignment (Reader on RG for current user)
# ─────────────────────────────────────────────
echo ""
echo "--- RBAC ---"
CURRENT_USER=$(az ad signed-in-user show --query "id" --output tsv 2>/dev/null || echo "")
if [[ -n "$CURRENT_USER" ]]; then
  echo "Creating test Reader role assignment on $RG..."
  az role assignment create \
    --assignee "$CURRENT_USER" \
    --role "Reader" \
    --scope "/subscriptions/$(az account show --query id --output tsv)/resourceGroups/$RG" \
    --output none 2>/dev/null || echo "  (role assignment may already exist)"
else
  echo "  Skipping RBAC test (could not determine signed-in user)"
fi

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
echo ""
echo "=== Phase 2 Sandbox Setup Complete ==="
echo ""
echo "Resources created in $RG:"
echo "  Key Vault:    $KEYVAULT_NAME (3 secrets, 1 key)"
echo "  Deployment:   bmaz-test-deploy (ARM template)"
echo "  SQL Server:   $SQL_SERVER_NAME (db: bmaz-test-db)"
echo "  PG Server:    $PG_SERVER_NAME (db: bmaz-test-db)"
echo "  RBAC:         Reader assignment on $RG"
echo ""
echo "Test with:"
echo "  export BMAZ_DEFAULT_RG=$RG"
echo "  source aliases"
echo "  keyvaults"
echo "  keyvaults | secrets"
echo "  keyvaults | secret-expiry"
echo "  deployments"
echo "  deployments | deployment-status"
echo "  deployments | deployment-outputs"
echo "  sql-servers"
echo "  sql-servers | sql-databases"
echo "  postgres-servers"
echo "  postgres-servers | postgres-databases"
echo "  role-assignments"
echo "  ad-users"
echo "  ad-groups"
echo ""
echo "Teardown: ./test/teardown-sandbox.sh (deletes entire $RG)"
echo ""
echo "NOTE: SQL password stored only in this output. Not saved anywhere."
echo "  SQL: $SQL_ADMIN / $SQL_PASSWORD"
echo "  PG:  $PG_ADMIN / $PG_PASSWORD"
