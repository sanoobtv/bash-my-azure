# bash-my-azure

> Simple but powerful CLI commands for managing Azure resources.
> Harnesses the power of Azure CLI (`az`), while abstracting away verbosity.

Inspired by and built upon the patterns of [bash-my-aws](https://github.com/mbailey/bash-my-aws) by [Mike Bailey](https://github.com/mbailey).

---

## Quick Start

```bash
$ rgs
prod-rg      australiaeast   Succeeded
staging-rg   australiaeast   Succeeded
dev-rg       westus2         Succeeded

$ BMAZ_DEFAULT_RG=prod-rg vms
prod-rg/web-vm  Standard_B1s  VM running  australiaeast

$ vms | vm-ip
prod-rg/web-vm  10.0.0.4  20.11.22.33

$ nsgs | nsg-rules
AllowSSH  Inbound  Allow  100  Tcp  22  *
```

## Features

- **Short, memorable commands** — `vms`, `vnets`, `nsgs`, `rgs`, `keyvaults`, `secrets`
- **Unix pipeline friendly** — pipe between commands naturally (`vms | vm-ip`)
- **Tab completion** — commands are real shell functions, so `vm[tab]` completes `vms`, `vm-ip`, … directly (also `bmaz [tab][tab]`)
- **Filter built-in** — `vms web` = `vms | grep web` with tighter columns
- **Self-documenting** — `<command> --help` prints usage and examples (e.g. `vms --help`)
- **Resource group aware** — `export BMAZ_DEFAULT_RG=prod-rg` once and every command is scoped to it
- **58 functions** across 15 service files
- **Works in bash 4+ and zsh** — tested on macOS and Linux

## Design Philosophy

Borrowed from bash-my-aws — every command follows three rules:

1. **List resources** with the first column being a pipe-friendly identifier (`rg/name`)
2. **Accept piped input** — downstream commands consume identifiers from upstream
3. **Human-readable output** — column-aligned, grep-friendly, no JSON noise

## Installation

### Prerequisites

- [Azure CLI](https://aka.ms/install-az) (v2.50+)
- bash 4+ or zsh
- [`jq`](https://jqlang.github.io/jq/) (only for `deployment-outputs`)
- `az login` completed

### Install

```bash
git clone https://github.com/<org>/bash-my-azure.git ~/.bash-my-azure
~/.bash-my-azure/install.sh
```

Then restart your shell or `source ~/.bashrc` / `source ~/.zshrc`.

`install.sh` adds a block to your shell rc that **sources the functions directly into your shell** (`for f in "$BMAZ_HOME"/lib/*-functions; do source "$f"; done`). That makes them fast (no subprocess per call), composable (you can wrap or override any function), and lets a plain `export BMAZ_DEFAULT_RG=prod-rg` reach every command.

To call a single command from another process or script — without loading the functions into your shell — use the `bmaz` wrapper (added to `PATH`):

```bash
bmaz vms
env BMAZ_DEFAULT_RG=prod-rg bmaz vms
```

### Verify

```bash
bmaz --version
bmaz --doctor
```

### Getting help

```bash
bmaz                    # or `bmaz --help` — list every command
vms --help              # usage + examples for a single command
bmaz vms --help         # same, via the wrapper
```

## Usage Examples (real output)

### Accounts & Subscriptions

```bash
$ accounts
a1b2c3d4-e5f6-7890-abcd-ef1234567890  My Dev Subscription   Enabled  True
b2c3d4e5-f6a7-8901-bcde-f12345678901  Production            Enabled  False

$ account-show
a1b2c3d4-e5f6-7890-abcd-ef1234567890  My Dev Subscription  d4e5f6a7-b8c9-0123-cdef-456789abcdef  Enabled
```

### Resource Groups

```bash
$ rgs
prod-rg      australiaeast   Succeeded
staging-rg   australiaeast   Succeeded
dev-rg       westus2         Succeeded

$ rg-resources prod-rg
prod-rg/app-vnet          Microsoft.Network/virtualNetworks        australiaeast
prod-rg/app-nsg           Microsoft.Network/networkSecurityGroups  australiaeast
prod-rg/appstore01        Microsoft.Storage/storageAccounts        australiaeast
prod-rg/web-vm            Microsoft.Compute/virtualMachines        australiaeast
prod-rg/app-kv            Microsoft.KeyVault/vaults                australiaeast
prod-rg/app-sql           Microsoft.Sql/servers                    australiaeast
prod-rg/app-pg            Microsoft.DBforPostgreSQL/flexibleServers  australiaeast
```

### Virtual Machines

```bash
$ vms
prod-rg/web-vm  Standard_B1s  VM running  australiaeast

$ vms | vm-status
prod-rg/web-vm  VM running

$ vms | vm-ip
prod-rg/web-vm  10.0.0.4  20.11.22.33
```

### Networking

```bash
$ vnets
prod-rg/app-vnet  10.0.0.0/16  australiaeast  Succeeded

$ subnets
prod-rg/app-vnet/app-subnet  10.0.0.0/24  Succeeded

$ nsgs
prod-rg/app-nsg  australiaeast  Succeeded

$ nsgs | nsg-rules
AllowSSH  Inbound  Allow  100  Tcp  22  *
```

### Network Troubleshooting (Azure's Reachability Analyzer)

```bash
# What routes does the VM's NIC see?
$ vms | vm-effective-routes
prod-rg/web-vm  Default  10.0.0.0/16  VnetLocal  None
prod-rg/web-vm  Default  0.0.0.0/0    Internet   None
prod-rg/web-vm  Default  10.0.0.0/8   None       None

# Where does traffic to 8.8.8.8 go next?
$ vm-next-hop prod-rg/web-vm 8.8.8.8
prod-rg/web-vm  8.8.8.8  Internet  None  System Route

# Would NSG rules block SSH inbound?
$ vm-test-flow prod-rg/web-vm Inbound TCP 10.0.0.4:22 203.0.113.1:*
prod-rg/web-vm  Allow  securityRules/AllowSSH

# Would NSG rules block RDP inbound?
$ vm-test-flow prod-rg/web-vm Inbound TCP 10.0.0.4:3389 203.0.113.1:*
prod-rg/web-vm  Deny  defaultSecurityRules/DenyAllInBound

# Full end-to-end connectivity test (requires NetworkWatcher extension)
$ vm-test-connectivity prod-rg/web-vm 10.1.0.4 5432
prod-rg/web-vm  10.1.0.4:5432  Reachable  12ms  2 hops
```

### Storage

```bash
$ storage-accounts
prod-rg/appstore01      australiaeast  StorageV2  Standard_LRS  Succeeded
prod-rg/backupstore02   australiaeast  StorageV2  Standard_LRS  Succeeded

$ blob-containers prod-rg/appstore01
app-data  None
```

### Key Vault & Secrets

```bash
$ keyvaults
prod-rg/app-kv  australiaeast  Succeeded  standard

$ secrets prod-rg/app-kv
app-kv  api-key       True  (never)
app-kv  cert-pass     True  2026-08-15T00:00:00+00:00
app-kv  db-password   True  2026-12-31T00:00:00+00:00

$ secret-expiry prod-rg/app-kv
app-kv  cert-pass     2026-08-15T00:00:00+00:00
app-kv  db-password   2026-12-31T00:00:00+00:00

$ keyvaults | keyvault-keys
https://app-kv.vault.azure.net/keys/encryption-key  True  None  None
```

### ARM Deployments

```bash
$ deployments
prod-rg/infra-deploy   Succeeded  2026-05-31T08:53:40.524591+00:00  Microsoft.Resources/deployments
prod-rg/vm-deploy      Succeeded  2026-05-31T08:16:43.445354+00:00  Microsoft.Resources/deployments

$ deployments | deployment-status
prod-rg/infra-deploy  Succeeded  2026-05-31T08:53:40.524591+00:00  PT27.0248686S

$ deployment-resources prod-rg/infra-deploy
Microsoft.Storage/storageAccounts  appstore01  Succeeded
```

### Databases

```bash
$ sql-servers
prod-rg/app-sql  australiaeast  Ready  sqladmin

$ sql-servers | sql-databases
prod-rg/app-sql  app-db  Basic  Online  2147483648

$ postgres-servers
prod-rg/app-pg  Australia East  Ready  16  Burstable

$ postgres-servers | postgres-databases
prod-rg/app-pg  app-db    UTF8
prod-rg/app-pg  postgres  UTF8
```

### Entra ID (Active Directory)

```bash
$ ad-users | head -3
alice@contoso.com   Alice Smith    None  None
bob@contoso.com     Bob Johnson    None  None
carol@contoso.com   Carol Lee      None  None

$ ad-groups | head -3
All Admins         Security  (none)
All Company        M365      Default group for everyone
PIM-GlobalAdmin    Security  PIM enabled group for GA access

$ ad-apps | head -3
My Web App       a1b2c3d4-1234-5678-abcd-ef1234567890  2025-07-30T20:50:05Z
API Gateway      b2c3d4e5-2345-6789-bcde-f12345678901  2023-03-28T02:07:02Z
CLI Tool         c3d4e5f6-3456-7890-cdef-123456789012  2023-07-06T08:57:24Z
```

### RBAC

```bash
$ role-definitions | head -5
Contributor                  BuiltInRole  Can manage all resources except access
Owner                        BuiltInRole  Can manage everything including access
Reader                       BuiltInRole  Can view all resources
Storage Blob Data Reader     BuiltInRole  Read access to blob data
Key Vault Secrets User       BuiltInRole  Read secret contents
```

### Piping (composability)

Commands output `rg/name` as the first column. Downstream commands parse this automatically:

```bash
# Get IPs for all VMs
$ vms | vm-ip
prod-rg/web-vm  10.0.0.4  20.11.22.33

# Get databases from all SQL servers
$ sql-servers | sql-databases
prod-rg/app-sql  app-db  Basic  Online  2147483648

# Get secrets from all keyvaults
$ keyvaults | secrets
app-kv  api-key      True  (never)
app-kv  db-password  True  2026-12-31T00:00:00+00:00

# Filter then act
$ vms | grep dev | vm-deallocate
Deallocating dev-rg/dev01...
```

### Regions

```bash
$ regions | head -5
asia               Asia                 None
asiapacific        Asia Pacific         None
australia          Australia            None
australiacentral   Australia Central    Asia Pacific
australiacentral2  Australia Central 2  Asia Pacific
```

## Available Commands

| Group | Commands |
|---|---|
| Account | `accounts`, `account-show`, `account-set` |
| Resource Groups | `rgs`, `rg-resources`, `rg-create`, `rg-delete` |
| VMs | `vms`, `vm-status`, `vm-ip`, `vm-start`, `vm-stop`, `vm-deallocate`, `vm-restart`, `vm-ssh`, `vm-delete` |
| VNets | `vnets`, `subnets`, `vnet-subnets` |
| NSGs | `nsgs`, `nsg-rules` |
| Network Watcher | `vm-effective-routes`, `vm-next-hop`, `vm-test-flow`, `vm-test-connectivity` |
| Storage | `storage-accounts`, `blob-containers`, `blob-container-blobs` |
| Key Vault | `keyvaults`, `keyvault-keys` |
| Secrets | `secrets`, `secret-show`, `secret-set`, `secret-expiry` |
| Deployments | `deployments`, `deployment-status`, `deployment-errors`, `deployment-outputs`, `deployment-resources`, `deployment-delete` |
| Databases | `sql-servers`, `sql-databases`, `postgres-servers`, `postgres-databases`, `mysql-servers`, `cosmosdb-accounts` |
| Entra ID | `ad-users`, `ad-groups`, `ad-group-members`, `ad-apps`, `ad-sp` |
| RBAC | `role-assignments`, `role-definitions`, `role-assignment-create`, `role-assignment-delete` |
| Regions | `regions` |

## AI Agent Support

This project ships with:
- **[`skills/SKILL.md`](skills/SKILL.md)** — AI agents auto-discover available commands
- **[`AGENTS.md`](AGENTS.md)** — Instructions for AI agents to contribute new functions

Point your AI agent at this repo and it can suggest commands or write new ones following conventions.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for human contributors.
See [AGENTS.md](AGENTS.md) for AI agent contributors.

## Acknowledgements

This project is a port of [bash-my-aws](https://github.com/mbailey/bash-my-aws) by [Mike Bailey](https://github.com/mbailey) — the original "pipe-skimming" pattern, `columnise` approach, and overall design philosophy come directly from his work. If you manage AWS resources, check out his project.

We'd been using similar functions for our day-to-day Azure BAU activities and consolidated them into this repo with the help of [GitHub Copilot](https://github.com/features/copilot) (Claude Opus).

## License

MIT — see [LICENSE](LICENSE)
