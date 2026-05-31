# Contributing to bash-my-azure

## Quick Start

1. Fork the repo
2. Clone: `git clone https://github.com/<your-fork>/bash-my-azure.git`
3. Branch: `git checkout -b feat/<service>-functions`
4. Implement (follow conventions below)
5. Run `scripts/build`
6. Lint + unit test: `shellcheck -s bash lib/*-functions` and `bats test/bmaz.bats`
7. Test against sandbox: `./test/setup-sandbox.sh`
8. Update `TEST-MATRIX.md`
9. Commit + PR

## Conventions

- **Read `AGENTS.md`** — same rules apply to humans and AI agents
- Function naming: `resource-action` (lowercase, hyphenated)
- Output: `--output tsv` + `--query` + `columnise`
- First column: `rg/name` for resource listings
- Destructive ops: confirm before executing

## Commit Style

Conventional commits:

```
feat(vm): add vm-resize function
fix(storage): handle empty container list
docs: update TEST-MATRIX with storage results
```

## PR Checklist

- [ ] `scripts/build` run (aliases + completions regenerated)
- [ ] `shellcheck -s bash lib/*-functions` clean (CI enforces this)
- [ ] `bats test/bmaz.bats` green (CI enforces this)
- [ ] `TEST-MATRIX.md` updated with new function rows
- [ ] Functions tested against sandbox sub (or noted as untested)
- [ ] No hardcoded subscription IDs or resource groups
- [ ] Destructive actions have confirmation prompt

## Testing

Two layers. CI (`.github/workflows/ci.yml`) runs the first on every push/PR; the second needs a real subscription.

### Unit tests (no Azure, no cost)

Pure-logic functions and pipe behavior run against a stubbed `az`:

```bash
bats test/bmaz.bats
```

Add a case here for any helper you introduce. See the stub setup in `test/bmaz.bats`.

### Sandbox tests (live Azure)

```bash
# Set up sandbox resources
export BMAZ_TEST_RG="bmaz-test-rg"
./test/setup-sandbox.sh

# Source functions locally
for f in lib/*-functions; do source "$f"; done

# Run your function
export BMAZ_DEFAULT_RG="$BMAZ_TEST_RG"
vms
vm-status

# Clean up
./test/teardown-sandbox.sh
```

## Code Review

- At least 1 approval required
- No force-push to `main`
- Squash merge preferred
