# HENGSHI CLI

[中文](./README.md) | [English](./README.en.md)

HENGSHI CLI 是 HENGSHI 官方命令行工具，面向人类与 AI Agent 提供统一的执行面，用来完成数据接入、HQL 查询、仪表板交付、权限动作以及 BI 运维工作流，并随发布一起提供官方 skills。

> 本发布说明面向公开可见仓库，但**不按开源协议授权**。对软件的安装、使用、复制、修改、分发与再授权，均以商业协议或北京衡石科技有限公司的其他书面授权为准，详见 [LICENSE](./LICENSE)。

[安装](#安装与快速开始) · [Agent Skills](#agent-skills) · [认证](#认证) · [命令面](#命令面) · [支持](#支持)

## 为什么选择 HENGSHI CLI？

- **Agent-Native 设计** —— 官方领域 skills 与 CLI 一起发布，让编码代理和常驻型 agent 沿着稳定 runbook 执行，而不是临时猜命令。
- **覆盖完整 BI 主链路** —— 一套命令树覆盖应用、数据集、仪表板、控件、权限、数据集成、Notebook 与调度相关工作流。
- **天然适合自动化** —— 原生支持 `table`、`json`、`yaml` 输出，降低人类和 AI 系统的解析成本。
- **执行前可预演** —— `--dry-run` 提供修改前预演面，让自动化更容易审查、审批与追踪。
- **面向企业真实环境** —— 系统 Keyring、OAuth / SSO、环境变量 token 流程，让 CLI 能进入交互式与自动化场景。

## 安装与快速开始

### 环境要求

- Linux / macOS / Windows

### 安装 CLI

请选择以下 **任意一种** 安装方式：

**方式一 —— 官方静态分发：**

```bash
curl -fsSL https://download.hengshi.com/cli/install.sh | sh
```

Windows PowerShell：

```powershell
irm https://download.hengshi.com/cli/install.ps1 | iex
```

如需在安装 CLI 的同时安装官方 skills，可直接传 flag：

```bash
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills --agent openclaw
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills --agent claude-code --agent github-copilot
```

Windows PowerShell：

```powershell
& ([scriptblock]::Create((irm https://download.hengshi.com/cli/install.ps1))) -WithSkills -Agent openclaw
```

不指定 `--agent` 时，installer 会按 bundled `supported-agents.tsv` 自动探测本机已存在的 agent 配置目录；显式传 `--agent` 时则直接写入对应 agent 的全局 skills 目录。

**方式二 —— 直接下载静态发布包：**

从以下地址下载对应平台的发布资产：

```text
https://download.hengshi.com/cli/<version>/
```

安装完成后，先确认二进制可用：

```bash
hbi --version
```

> 从 **2.0.0** 开始，对外命令名切到 `hbi`。现有本地配置和缓存凭据会自动复用，但旧的 `everest ...` 脚本需要同步更新。重新运行官方安装脚本做升级时，也会在 `hbi` 安装成功后清掉同目录遗留的 `everest` / `everest.exe`。

### 只安装 / 重装官方 skills

如果 CLI 已经装好，只想补装或重装官方 skills，直接重跑 installer 并带 `--with-skills` 即可。

OpenClaw：

```bash
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills --agent openclaw
```

自动探测本机已安装 agent：

```bash
curl -fsSL https://download.hengshi.com/cli/install.sh | sh -s -- --with-skills
```

### 检查更新与执行更新

如果当前安装来自官方 installer，CLI 也支持直接在本机检查和执行升级：

```bash
hbi update --check
hbi update
hbi update --with-skills
hbi update --version 2.1.0
```

`hbi update --check` 不依赖已保存登录态或 `HBI_TOKEN` / `--token`；如果当前安装还不是 updater-managed，命令会提示你先重跑一次官方 installer。

### 配置并开始使用

```bash
# 配置目标实例
export HBI_HOST="<你的-hengshi-sense-实例>"
# 裸 host 也可以；省略 scheme 时 CLI 会先探测 https://，失败后再试 http://
# 也支持带二级路径的 host，例如 HBI_HOST="platform.hengshi.org/bi"

# 认证（推荐 device-login；Sense 6.2.1+）
hbi auth login --device-login

# Client ID / Secret（次选；用于非交互或更老主机）
export HBI_CLIENT_ID="<client_id>"
export HBI_CLIENT_SECRET="<client_secret>"
hbi auth login

# 远程/SSH/openclaw：Sense 6.2.1+ 支持 device-login（浏览器确认即可）；
# 更老版本会在提供 client credentials 时自动回退。
hbi auth status

# 开始使用
hbi app list --area personal-area --root
```

如果只是临时覆盖一次访问令牌，也可以直接注入：

```bash
export HBI_TOKEN="<token>"
hbi --token "<token>" auth status
```

## Agent Skills

HENGSHI CLI 提供官方 skills，让 Agent 在不同环境里复用同一套领域边界与执行模式。

代表性 skills 包括：

- `hbi-core` —— 认证、配置、输出、术语与执行规则
- `hbi-data` —— 数据连接、数据集、指标与度量工作流
- `hbi-dashboard` —— 仪表板规划、布局与控件 authoring
- `hbi-permission` —— 权限查询、授权与回收
- `hbi-workflow` —— 跨领域编排与顺序控制
- `hql-expert` —— HQL / HE 公式与表达式编写

官方 installer 会把 bundled public skills 直接写入支持的 agent skills 目录，并在升级时清理旧的 `everest-*` skill 目录。对外 bundled skill 集合只包含 `hbi-*` 与 `hql-expert`；仓库维护、评测工作区等内部 skills 不随 public release 分发。

## 认证

```bash
# 设备登录（推荐；Sense 6.2.1+）
HBI_HOST="<你的-hengshi-sense-实例>" hbi auth login --device-login

# Client ID / Secret（次选；用于非交互或更老主机）
HBI_HOST="<你的-hengshi-sense-实例>" \
HBI_CLIENT_ID="<client_id>" \
HBI_CLIENT_SECRET="<client_secret>" \
hbi auth login

# 查看当前认证状态
hbi auth status --output json

# 自动化模式
export HBI_TOKEN="<token>"
```

## 命令面

HENGSHI CLI 被设计成面向真实 BI 交付流程的执行面。

```bash
# 读取当前上下文
hbi dataset list --app retail-ops --output json

# 创建仪表板
hbi dashboard create --app retail-ops "区域销售驾驶舱"

# 新增图表
hbi element chart create --dashboard dsh_2048 --app retail-ops --dataset sales_daily line

# 安全预演一条权限变更
hbi authorize grant app app_42 --user 123:editor --dry-run
```

## 支持

- Docs: https://docs.hengshi.com/v6.2/cli.html
- GitHub Releases（手动下载与 Release Note）: https://github.com/hengshi/cli/releases
- 静态发布目录请使用版本化路径：`https://download.hengshi.com/cli/<version>/`
