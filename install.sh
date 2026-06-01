#!/bin/bash
#
# install.sh — Install bash-my-azure
#
# Usage:
#   git clone https://github.com/sanoobtv/bash-my-azure.git ~/.bash-my-azure
#   ~/.bash-my-azure/install.sh
#
# Or one-liner:
#   curl -sL https://raw.githubusercontent.com/sanoobtv/bash-my-azure/main/install.sh | bash

set -euo pipefail

BMAZ_HOME="${BMAZ_HOME:-$HOME/.bash-my-azure}"
BMAZ_REPO="${BMAZ_REPO:-https://github.com/sanoobtv/bash-my-azure.git}"

# If running from curl pipe, clone first
if [[ ! -d "$BMAZ_HOME" ]]; then
  if [[ "$BMAZ_REPO" == *"<org>"* ]]; then
    echo "ERROR: repo URL not configured. Set BMAZ_REPO to your clone URL, e.g.:" >&2
    echo "  BMAZ_REPO=https://github.com/you/bash-my-azure.git $0" >&2
    exit 1
  fi
  echo "Cloning bash-my-azure to $BMAZ_HOME..."
  git clone "$BMAZ_REPO" "$BMAZ_HOME"
fi

# Detect shell
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
  zsh)  RC_FILE="$HOME/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)    RC_FILE="$HOME/.bashrc"; echo "Warning: Unsupported shell '$SHELL_NAME', defaulting to .bashrc" ;;
esac

# The lines to add
MARKER="# bash-my-azure"
SOURCE_BLOCK="$MARKER
export BMAZ_HOME=\"\${BMAZ_HOME:-\$HOME/.bash-my-azure}\"
export PATH=\"\$PATH:\$BMAZ_HOME/bin\"
export BMAZ_COLUMNISE_ONLY_WHEN_TERMINAL_PRESENT=true
# Keep az output pipeline-clean: no color codes, no upgrade/warning chatter on stdout
export AZURE_CORE_NO_COLOR=\"\${AZURE_CORE_NO_COLOR:-1}\"
export AZURE_CORE_ONLY_SHOW_ERRORS=\"\${AZURE_CORE_ONLY_SHOW_ERRORS:-1}\"

# Load functions directly into your shell: fast (no per-call subprocess),
# composable, and picks up a plain 'export BMAZ_DEFAULT_RG=...'.
# Temporarily suppress alias expansion so sourced fn defs don't collide
# with identically-named aliases from other tools (e.g. bash-my-aws).
[[ -n \"\${ZSH_VERSION:-}\" ]] && setopt NO_ALIASES
for f in \"\$BMAZ_HOME\"/lib/*-functions; do source \"\$f\"; done
[[ -n \"\${ZSH_VERSION:-}\" ]] && setopt ALIASES

# For ZSH users:
if [[ -n \"\$ZSH_VERSION\" ]]; then
  autoload -U +X compinit && compinit
  autoload -U +X bashcompinit && bashcompinit
fi

source \"\$BMAZ_HOME/bash_completion.sh\"
# end bash-my-azure"

# Idempotent: only add if not already present
if grep -q "$MARKER" "$RC_FILE" 2>/dev/null; then
  echo "bash-my-azure already configured in $RC_FILE"
else
  echo "" >> "$RC_FILE"
  echo "$SOURCE_BLOCK" >> "$RC_FILE"
  echo "Added bash-my-azure config to $RC_FILE"
fi

# Run build to ensure aliases/completions are fresh
"$BMAZ_HOME/scripts/build"

# Verify
echo ""
echo "Installation complete!"
echo "  BMAZ_HOME: $BMAZ_HOME"
echo "  Shell RC:  $RC_FILE"
echo ""
echo "Restart your shell or run:"
echo "  source $RC_FILE"
echo ""

# Check az CLI
if command -v az &>/dev/null; then
  az_ver=$(az version -o yaml 2>/dev/null | grep '^azure-cli:' | awk '{print $2}') || az_ver=""
  echo "az CLI found: ${az_ver:-unknown version}"
else
  echo "WARNING: az CLI not found. Install: https://aka.ms/install-az"
fi
