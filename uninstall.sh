#!/bin/bash
#
# uninstall.sh — Remove bash-my-azure from shell config
#

set -euo pipefail

BMAZ_HOME="${BMAZ_HOME:-$HOME/.bash-my-azure}"

# Detect shell
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
  zsh)  RC_FILE="$HOME/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)    RC_FILE="$HOME/.bashrc" ;;
esac

# Remove config block from RC file
if grep -q "# bash-my-azure" "$RC_FILE" 2>/dev/null; then
  # Remove lines between markers
  sed -i.bak '/# bash-my-azure/,/# end bash-my-azure/d' "$RC_FILE"
  rm -f "${RC_FILE}.bak"
  echo "Removed bash-my-azure config from $RC_FILE"
else
  echo "No bash-my-azure config found in $RC_FILE"
fi

echo ""
read -p "Delete $BMAZ_HOME directory? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf "$BMAZ_HOME"
  echo "Deleted $BMAZ_HOME"
else
  echo "Kept $BMAZ_HOME"
fi

echo ""
echo "Uninstall complete. Restart your shell."
