# Contributing via AI Agent

Instructions for AI agents (Copilot, Cursor, Cline, etc.) to create new bash-my-azure functions while maintaining project conventions.

## Before Writing Code

1. Read `lib/shared-functions` — understand `skim-stdin`, `columnise`, `__bmaz_*` helpers
2. Read this file for naming and structure rules
3. Check `docs/PLAN.md` for which services/phases are planned
4. Check `docs/TEST-MATRIX.md` to see what's already done

## Naming Conventions

| Pattern | Example | Rule |
|---|---|---|
| List resources | `vms`, `vnets`, `nsgs` | Plural noun |
| Resource action | `vm-stop`, `nsg-rules` | `resource-action` |
| Internal helpers | `__bmaz_parse_resource` | Double-underscore prefix |
| Env vars | `BMAZ_DEFAULT_RG` | `BMAZ_` prefix, UPPER_SNAKE |
| File names | `lib/vm-functions` | `lib/<service>-functions` |

## Function Structure

Every function follows this skeleton:

```bash
resource-action() {

  # Brief one-line description
  #
  #     USAGE: resource-action rg/name [rg/name]
  #
  #     $ resources | resource-action
  #     output-col1  output-col2

  [[ "${1:-}" == --help ]] && __bmaz_help && return 0

  local resource_ids=($(skim-stdin "$@"))
  [[ ${#resource_ids[@]} -eq 0 ]] && __bmaz_usage "rg/name [rg/name]" && return 1

  local resource_id
  for resource_id in "${resource_ids[@]}"; do
    __bmaz_parse_resource "$resource_id" || return 1
    az <service> <command>              \
      --resource-group "$_bmaz_rg"      \
      --name "$_bmaz_name"              \
      --output tsv                      \
      --query "<jmespath-expression>"
  done |
    columnise
}
```

## Rules

1. **Output format:** Always `--output tsv` with `--query`. Pipe through `columnise`.
2. **First column = `rg/name`** for listing fns. Use `join('/', [resourceGroup, name])` in JMESPath.
3. **Pipe input:** Use `skim-stdin "$@"` to accept both args and piped input.
4. **Filters:** Listing fns accept filter args via `__bmaz_read_filters` + `grep -E`.
5. **RG scoping:** Listing fns check `$BMAZ_DEFAULT_RG` for optional scope.
6. **Destructive actions:** Must confirm with user (see `vm-delete`, `rg-delete` for pattern).
7. **No `--no-wait` on read ops.** Use `--no-wait` on write ops (start, stop, delete).
8. **Comments + `--help`:** Brief description + USAGE + example output in the leading comment block. That block *is* the help text — add `[[ "${1:-}" == --help ]] && __bmaz_help && return 0` right after it so `<command> --help` prints it (`__bmaz_help` extracts the comment block from the lib file).
9. **Sorting:** Sort output by first column (`LC_ALL=C sort -t$'\t' -k 1`).
10. **Input arrays:** Collect piped/arg input as an array — `local ids=($(skim-stdin "$@"))` — and iterate quoted: `for id in "${ids[@]}"`. Guard with `[[ ${#ids[@]} -eq 0 ]]`. (Never `for id in $ids` — unquoted word-splitting trips ShellCheck SC2086.)
11. **Lint + test clean:** `shellcheck -s bash lib/*-functions` must pass (config in `.shellcheckrc`), and `bats test/bmaz.bats` must stay green. Add a test for any pure-logic helper you introduce.

## Creating a New Service File

1. Create `lib/<service>-functions` with `#!/bin/bash` header
2. First function = plural listing (e.g., `lbs`, `acrs`, `webapps`)
3. Add detail/action functions after listing works
4. Run `scripts/build` to regenerate aliases + completions + `skills/SKILL.md`
5. Add entries to `docs/TEST-MATRIX.md` (status: 🔲 untested)
6. Test against sandbox subscription if available

## JMESPath Tips for Azure

```bash
# Simple field selection
--query "[].{Name:name, RG:resourceGroup}"

# Composite ID (rg/name pattern)
--query "[].{Id:join('/', [resourceGroup, name]), ...}"

# Nested values
--query "[].{Sku:sku.name, Tier:sku.tier}"

# Filtering within query
--query "[?provisioningState=='Succeeded'].{...}"

# Array first element
--query "[].{IP:ipConfigurations[0].privateIpAddress}"
```

## After Writing

1. `scripts/build` — regenerate aliases, completions, `skills/SKILL.md`
2. `shellcheck -s bash lib/*-functions` — must be clean
3. `bats test/bmaz.bats` — must pass (add a case for new pure-logic helpers)
4. Update `docs/TEST-MATRIX.md` — add new rows with ⬜ or 🔲 status
5. Test locally: `source lib/<service>-functions && <fn-name>`
6. Commit: `feat(<service>): add <fn-name> functions`

## Don'ts

- Don't modify `aliases` or `bash_completion.sh` manually (auto-generated)
- Don't reach for `--output json` + `jq` as a default — use `--output tsv` + `--query`. `jq` is allowed **only** for shapes JMESPath can't render as TSV (e.g. iterating an object keyed by name, as `deployment-outputs` does). If you add a `jq` dependency, declare it in the README and `bmaz --doctor`.
- Don't use `python3` (or any non-shell interpreter) for parsing — keep the toolchain to `az` + coreutils + `jq`.
- Don't hardcode subscription IDs or resource groups
- Don't add functions that require interactive input (except destructive confirms)
- Don't skip `__bmaz_parse_resource` for action fns — it handles the rg/name split
