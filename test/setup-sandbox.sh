#!/bin/bash
#
# test/setup-sandbox.sh
#
# Create minimal Azure resources for testing bash-my-azure functions.
# Requires: az CLI authenticated, active subscription set.
#
# Usage:
#   export BMAZ_TEST_RG="bmaz-test-rg"
#   export BMAZ_TEST_LOCATION="australiaeast"
#   ./test/setup-sandbox.sh

set -euo pipefail

RG="${BMAZ_TEST_RG:-bmaz-test-rg}"
LOCATION="${BMAZ_TEST_LOCATION:-australiaeast}"
VM_NAME="bmaz-test-vm"
VNET_NAME="bmaz-test-vnet"
SUBNET_NAME="bmaz-test-subnet"
NSG_NAME="bmaz-test-nsg"
STORAGE_NAME="bmazteststore$$"  # append PID for uniqueness

echo "=== bash-my-azure Sandbox Setup ==="
echo "Resource Group: $RG"
echo "Location:       $LOCATION"
echo ""

# Resource Group
echo "Creating resource group..."
az group create --name "$RG" --location "$LOCATION" --output none

# VNet + Subnet
echo "Creating VNet and Subnet..."
az network vnet create \
  --resource-group "$RG" \
  --name "$VNET_NAME" \
  --address-prefix "10.0.0.0/16" \
  --subnet-name "$SUBNET_NAME" \
  --subnet-prefix "10.0.0.0/24" \
  --output none

# NSG
echo "Creating NSG..."
az network nsg create \
  --resource-group "$RG" \
  --name "$NSG_NAME" \
  --output none

# Add a sample rule
az network nsg rule create \
  --resource-group "$RG" \
  --nsg-name "$NSG_NAME" \
  --name "AllowSSH" \
  --priority 100 \
  --protocol Tcp \
  --destination-port-ranges 22 \
  --access Allow \
  --direction Inbound \
  --output none

# Storage Account
echo "Creating storage account..."
az storage account create \
  --resource-group "$RG" \
  --name "$STORAGE_NAME" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --output none

# Blob Container
echo "Creating blob container..."
az storage container create \
  --account-name "$STORAGE_NAME" \
  --name "bmaz-test-container" \
  --auth-mode login \
  --output none 2>/dev/null || echo "  (may need Storage Blob Data Contributor role)"

# VM (small, cheap)
echo "Creating VM (this takes a minute)..."
az vm create \
  --resource-group "$RG" \
  --name "$VM_NAME" \
  --image "Ubuntu2204" \
  --size "Standard_B1s" \
  --vnet-name "$VNET_NAME" \
  --subnet "$SUBNET_NAME" \
  --nsg "$NSG_NAME" \
  --admin-username "azureuser" \
  --generate-ssh-keys \
  --no-wait \
  --output none

echo ""
echo "=== Sandbox Setup Complete ==="
echo ""
echo "Resources created in $RG:"
echo "  VM:       $VM_NAME"
echo "  VNet:     $VNET_NAME"
echo "  Subnet:   $SUBNET_NAME"
echo "  NSG:      $NSG_NAME"
echo "  Storage:  $STORAGE_NAME"
echo ""
echo "Set these for testing:"
echo "  export BMAZ_TEST_RG=\"$RG\""
echo "  export BMAZ_DEFAULT_RG=\"$RG\""
echo "  export BMAZ_TEST_STORAGE=\"$STORAGE_NAME\""
echo ""
echo "Teardown: ./test/teardown-sandbox.sh"
