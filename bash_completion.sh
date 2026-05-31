# DO NOT MANUALLY MODIFY THIS FILE.
# Use 'scripts/build' to regenerate if required.

# Complete bmaz with all function names
_bmaz_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local commands="$(cat "${BMAZ_HOME:-$HOME/.bash-my-azure}/functions")"
  COMPREPLY=($(compgen -W "$commands" -- "$cur"))
}
complete -F _bmaz_completions bmaz

# Complete individual commands that accept resource group names
_bmaz_rg_completions() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local rgs="$(az group list --query "[].name" -o tsv 2>/dev/null)"
  COMPREPLY=($(compgen -W "$rgs" -- "$cur"))
}

complete -F _bmaz_rg_completions rg-resources
complete -F _bmaz_rg_completions rg-delete
