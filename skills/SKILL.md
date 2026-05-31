---
name: bash-my-azure
description: >
  Short, pipeable bash functions for managing Azure resources via az CLI.
  Use when user asks about Azure VMs, VNets, storage, deployments, NSGs,
  resource groups, or any Azure infra task from terminal. Commands follow
  the bash-my-aws pattern: list with plural noun, act with resource-action.
triggers:
  - azure vm
  - az cli
  - resource group
  - vnet subnet
  - azure storage
  - bmaz
  - bash-my-azure
  - azure nsg
  - azure networking
---

# bash-my-azure

Simple, powerful CLI commands for managing Azure resources. Port of [bash-my-aws](https://github.com/mbailey/bash-my-aws).

## Patterns

- **List:** `vms`, `vnets`, `nsgs`, `rgs`, `storage-accounts`, `regions`
- **Action:** `vm-stop`, `vm-ssh`, `rg-delete`, `nsg-rules`
- **Pipe-friendly:** `vms | grep web | vm-stop`
- **Filter built-in:** `vms web` (same as `vms | grep web` but tighter columns)

## Key Concepts

- **Pipe token = `rg/name`** — e.g. `prod-rg/web01`. Action fns split to get both parts.
- **`$BMAZ_DEFAULT_RG`** — Set to scope listings to one RG and use short names.
- **`skim-stdin`** — First column from piped input becomes the argument list.
- **`columnise`** — Tab-separated output formatted into aligned columns.

## Environment Variables

| Variable | Purpose |
|---|---|
| `BMAZ_HOME` | Install directory (default: `~/.bash-my-azure`) |
| `BMAZ_DEFAULT_RG` | Default resource group for commands |
| `BMAZ_COLUMNISE_ONLY_WHEN_TERMINAL_PRESENT` | Skip column formatting when piping |

<!-- COMMANDS-START -->

### account
- `accounts`
- `account-show`
- `account-set`

### ad
- `ad-users`
- `ad-groups`
- `ad-group-members`
- `ad-apps`
- `ad-sp`

### db
- `sql-servers`
- `sql-databases`
- `postgres-servers`
- `postgres-databases`
- `mysql-servers`
- `cosmosdb-accounts`

### deployment
- `deployments`
- `deployment-status`
- `deployment-errors`
- `deployment-outputs`
- `deployment-resources`
- `deployment-delete`

### keyvault
- `keyvaults`
- `keyvault-keys`

### network-watcher
- `vm-effective-routes`
- `vm-next-hop`
- `vm-test-flow`
- `vm-test-connectivity`

### nsg
- `nsgs`
- `nsg-rules`

### rbac
- `role-assignments`
- `role-definitions`
- `role-assignment-create`
- `role-assignment-delete`

### region
- `regions`

### rg
- `rgs`
- `rg-resources`
- `rg-create`
- `rg-delete`

### secret
- `secrets`
- `secret-show`
- `secret-set`
- `secret-expiry`

### shared
- `skim-stdin`
- `columnise`

### storage
- `storage-accounts`
- `blob-containers`
- `blob-container-blobs`

### vm
- `vms`
- `vm-status`
- `vm-ip`
- `vm-start`
- `vm-stop`
- `vm-deallocate`
- `vm-restart`
- `vm-ssh`
- `vm-delete`

### vnet
- `vnets`
- `subnets`
- `vnet-subnets`

<!-- COMMANDS-END -->

## Writing New Functions

See [AGENTS.md](../AGENTS.md) for conventions, templates, and contribution workflow.

## Test Status

See [TEST-MATRIX.md](../docs/TEST-MATRIX.md) for current test coverage.
