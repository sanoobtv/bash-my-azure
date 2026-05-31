#!/bin/bash
#
# test/teardown-sandbox.sh
#
# Delete all test resources by removing the resource group.
#
# Usage:
#   ./test/teardown-sandbox.sh

set -euo pipefail

RG="${BMAZ_TEST_RG:-bmaz-test-rg}"

echo "=== bash-my-azure Sandbox Teardown ==="
echo ""
echo "This will DELETE resource group: $RG"
echo "All resources within it will be destroyed."
echo ""

read -p "Are you sure? [y/N] " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Deleting $RG (this may take a few minutes)..."
  az group delete --name "$RG" --yes --no-wait
  echo "Delete initiated (--no-wait). Check Azure portal for completion."
else
  echo "Cancelled."
fi
