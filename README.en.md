# HENGSHI CLI

[中文](./README.md) | [English](./README.en.md)

The official HENGSHI CLI, built for humans and AI Agents. It provides a unified command surface for data access, HQL, dashboards, permissions, and operational workflows across HENGSHI BI, and ships with official skills for agent execution.

> This public release surface is source-visible, but it is **not licensed as open source**. Installation, use, copying, modification, distribution, and sublicensing of the software are governed by a commercial agreement or other written authorization from Beijing Hengshi Technology Co., Ltd. See [LICENSE](./LICENSE).

[Installation](#installation--quick-start) · [Agent Skills](#agent-skills) · [Authentication](#authentication) · [Command Surface](#command-surface) · [Support](#support)

## Why HENGSHI CLI?

- **Agent-Native Design** — Official domain skills ship with the CLI so coding agents and persistent agents can follow stable runbooks instead of guessing commands.
- **Wide BI Coverage** — One command tree covers core HENGSHI domains including applications, datasets, dashboards, elements, permissions, pipelines, notebooks, and scheduler-facing workflows.
- **Structured for Automation** — Native `table`, `json`, and `yaml` output formats reduce parsing overhead for both humans and AI systems.
- **Safe to Review Before Execution** — `--dry-run` provides a preview layer before mutation, making automation easier to audit and approve.
- **Enterprise-Ready Authentication** — Keyring-backed storage, OAuth / SSO support, and environment-based token flows fit both interactive and automated environments.

## Installation & Quick Start

### Requirements

- Linux / macOS / Windows

### Install

Choose **one** of the following methods:

**Option 1 — Direct download:**

```bash
curl -fsSL https://download.hengshi.com/cli/install.sh | sh
```

Windows PowerShell:

```powershell
irm https://download.hengshi.com/cli/install.ps1 | iex
```

Optional: install the CLI and official skills in one step:

```bash
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills --agent openclaw
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills --agent claude-code --agent github-copilot
```

Windows PowerShell:

```powershell
& ([scriptblock]::Create((irm https://download.hengshi.com/cli/install.ps1))) -WithSkills -Agent openclaw
```

If `--agent` is omitted, the installer auto-detects existing local agent config directories from the bundled `supported-agents.tsv`. If `--agent` is provided, it installs directly into that agent's global skills directory.

**Option 2 — Download the static release archive directly:**

Download the release asset for your platform from:

```text
https://download.hengshi.com/cli/<version>/
```

After installation, verify the binary:

```bash
hbi --version
```

> Starting with **2.0.0**, the customer-facing command is `hbi`. Existing local config and cached credentials are reused automatically, but any old `everest ...` scripts need to be updated. Re-running the official installer also removes a same-directory legacy `everest` / `everest.exe` binary after `hbi` is installed successfully.

### Install or refresh official skills only

If the CLI binary is already installed, just re-run the installer with `--with-skills`.

For OpenClaw:

```bash
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills --agent openclaw
```

Auto-detect locally installed agents:

```bash
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills
```

### Check for updates and run updates

If the current install came from the official installer, the CLI can also check and apply upgrades locally:

```bash
hbi update --check
hbi update
hbi update --with-skills
hbi update --version 2.1.0
```

`hbi update --check` is auth-free; it does not require saved credentials or `HBI_TOKEN` / `--token`. If the current install is not updater-managed yet, the command tells you to re-run the official installer once first.

### Configure & Use

```bash
# Configure target instance
export HBI_HOST="<your-hengshi-sense-instance>"
# Bare host is fine; when scheme is omitted the CLI probes https:// first, then http://
# Subpaths are supported too, e.g. HBI_HOST="platform.hengshi.org/bi"

# Authenticate (device login recommended; Sense 6.2.1+)
hbi auth login --device-login

# Client ID / Secret (secondary; non-interactive or older hosts)
export HBI_CLIENT_ID="<client_id>"
export HBI_CLIENT_SECRET="<client_secret>"
hbi auth login

# Remote CLI / SSH / openclaw: approve in any browser; older hosts fall back to client credentials if set.
hbi auth status

# Start using the CLI
hbi app list --area personal-area --root
```

For a temporary access-token override, you can inject it directly:

```bash
export HBI_TOKEN="<token>"
hbi --token "<token>" auth status
```

## Agent Skills

HENGSHI CLI provides official skills so agents can reuse the same domain boundaries and execution patterns across environments.

Representative skills include:

- `hbi-core` — auth, config, output, terminology, and execution rules
- `hbi-data` — connection, dataset, metric, and measure workflows
- `hbi-dashboard` — dashboard planning, layout, and element authoring
- `hbi-permission` — permission queries, grants, and revokes
- `hbi-workflow` — cross-domain orchestration and sequencing
- `hql-expert` — HQL / HE formula and expression authoring

The official installer writes bundled public skills directly into supported agent skill directories and removes legacy `everest-*` skill folders during upgrade. The public bundled skill set is limited to `hbi-*` and `hql-expert`; repo-maintenance skills and evaluation workspaces stay private.

## Authentication

```bash
# Device login (recommended; Sense 6.2.1+)
HBI_HOST="<your-hengshi-sense-instance>" hbi auth login --device-login

# Client ID / Secret (secondary; non-interactive or older hosts)
HBI_HOST="<your-hengshi-sense-instance>" \
HBI_CLIENT_ID="<client_id>" \
HBI_CLIENT_SECRET="<client_secret>" \
hbi auth login

# Check current auth status
hbi auth status --output json

# Automation mode
export HBI_TOKEN="<token>"
```

## Command Surface

HENGSHI CLI is designed as an execution surface for real BI delivery workflows.

```bash
# Read current context
hbi dataset list --app retail-ops --output json

# Create a dashboard
hbi dashboard create --app retail-ops "Regional Sales Cockpit"

# Add a chart
hbi element chart create --dashboard dsh_2048 --app retail-ops --dataset sales_daily line

# Preview a permission change safely
hbi authorize grant app app_42 --user 123:editor --dry-run
```

## Support

- Docs: https://docs.hengshi.com/v6.2/cli.html
- GitHub Releases (manual downloads and release notes): https://github.com/hengshi/cli/releases
- Use the versioned static release path: `https://download.hengshi.com/cli/<version>/`
