# Changelog

## [Unreleased]

### Fixed
- `vm-ssh` selected the wrong VM — bash array index `[1]` → `[0]`
- `bin/bmaz` "disable pager" was a no-op; now sets `AZURE_CORE_NO_COLOR=1` + `AZURE_CORE_ONLY_SHOW_ERRORS=1`
- `__bmaz_read_filters` treated filter text as a `printf` format (broke on `%`); now `printf '%s'`, and all call sites quoted
- `__bmaz_error` / `__bmaz_usage` mixed string and array args (`$@` → `$*`) — ShellCheck SC2145
- `blob-container-blobs` passed an unquoted array slice (`${@:3}` → `"${@:3}"`) — ShellCheck SC2068
- Removed dead `local vms_input` capture in `vms()`

### Changed
- **Install now sources the functions directly into your shell** instead of registering aliases that shell out to `bin/bmaz` on every call. Removes the per-call subprocess + 15-file re-source overhead, restores composability, and lets a plain `export BMAZ_DEFAULT_RG=...` reach every command (previously it had to be a command-prefix). `bin/bmaz` is retained for cross-process use (`bmaz vms`); `AZURE_CORE_NO_COLOR`/`AZURE_CORE_ONLY_SHOW_ERRORS` are now exported from the shell rc block so sourced functions get the same clean output.
- Removed the `python3` runtime dependency: `vm-test-connectivity` parses via JMESPath `length(hops)`; `deployment-outputs` uses `jq`
- `jq` declared as a (narrow) dependency in README and checked by `bmaz --doctor`
- Removed unused `__bmaz_check_auth` helper
- Action functions standardized on the quoted-array input pattern (`"${ids[@]}"`)
- `install.sh` reads `BMAZ_REPO` and fails loudly instead of cloning a `<org>` placeholder URL

### Added
- Per-command `--help`: `<command> --help` prints the function's doc block (usage + examples), extracted from the lib file by the new `__bmaz_help` helper. `bmaz` with no args (or `--help`) lists every command.
- `test/bmaz.bats` — unit tests with a stubbed `az` (no live Azure)
- `.github/workflows/ci.yml` — ShellCheck + Bats on every push/PR
- `.shellcheckrc` — scoped suppressions for intentional house-style patterns
- `REVIEW.md` — engineering review and roadmap

## [0.1.0] - 2026-05-28

### Added
- Initial Phase 1 implementation
- `lib/shared-functions` — skim-stdin, columnise, __bmaz_* helpers
- `lib/account-functions` — accounts, account-show, account-set
- `lib/rg-functions` — rgs, rg-resources, rg-create, rg-delete
- `lib/vm-functions` — vms, vm-status, vm-ip, vm-start, vm-stop, vm-deallocate, vm-restart, vm-ssh, vm-delete
- `lib/vnet-functions` — vnets, subnets, vnet-subnets
- `lib/nsg-functions` — nsgs, nsg-rules
- `lib/storage-functions` — storage-accounts, blob-containers, blob-container-blobs
- `lib/region-functions` — regions
- `bin/bmaz` wrapper script
- `install.sh` / `uninstall.sh`
- `scripts/build` — auto-generate aliases, completions, SKILL.md
- `SKILL.md` — AI agent skill definition
- `AGENTS.md` — AI agent contribution guide
- `CONTRIBUTING.md` — Human contribution guide
- `TEST-MATRIX.md` — Shared test status tracking
- `test/setup-sandbox.sh` / `test/teardown-sandbox.sh`
