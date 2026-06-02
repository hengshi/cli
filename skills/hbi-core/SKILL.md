---
name: hbi-core
description: "HBI CLI 核心技能。只要任务涉及 hbi auth、preferences/config、output、search、公共术语、空间概念、错误处理或通用执行规范，就必须先使用这个技能。其他 Everest 技能都以本技能为前置。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi --help"
---

# HBI Core

> 任何 HBI CLI 任务先读本技能，再决定是否切换到 `hbi-app`、`hbi-data`、`hbi-data-modeling`、`hbi-dashboard` 等领域技能。
>
> 如果任务涉及精确的资源名、空间名、场景名、权限名或它们的英文别名，继续读取 `references/terminology.md`。本文件只保留高频摘要。
>
> 如果任务要写 `auth` / `preferences` 这类配置对象的 `--file/--value`，继续读取 `references/config-payloads.md`。

## GUI 术语对照

以下术语以 Lhotse 的 `packages/i18n/locales/zh-CN.json` 为准：

| CLI 命令名 | 面向用户的中文术语 | 备注 |
|---|---|---|
| `app` | 应用 | Everest 的主容器 |
| `dashboard` | 仪表盘 | 应用内可视化页面 |
| `dataset` | 数据集 | 数据模型与数据源封装 |
| `data-model` | 数据模型 | 数据集关系、联表、预览、查询 |
| `connection` | 数据连接 | 外部数据源接入 |
| `measure` | 业务指标 | 对应 Business Metric，业务语义更强 |
| `metric` | 原子指标 | 对应 Atomic Metric，不要和 `measure` 混用 |
| `subject` | 主题域 | 组织业务指标 |
| `kanban` | 分析看板 | 业务指标中心的看板 |
| `element` | 控件 | 图表、过滤器、容器、图片、文本 |

和用户交流时，优先使用中文产品术语；写命令时保留英文命令名。

## 顶层命令入口

先从这些顶层命令入口判断任务落在哪个领域：

- `auth`
- `app`
- `dataset`
- `data-model`
- `connection`
- `folder`
- `metric`
- `measure`
- `dashboard`
- `data-alert`
- `data-agent`
- `pipeline`
- `notebook`
- `scheduler`
- `search`
- `element`
- `user`
- `user-group`
- `org`
- `user-attr`
- `tenant`
- `subject`
- `kanban`
- `permission`
- `authorize`
- `logs`
- `preferences`
- `config`

不要引用旧文档里已经漂移的参数名，例如 `--app-id`。当前源码里高频命令大多使用 `--app`。

## 认证与配置

### `auth` 有两条命令面，不要混用

#### 1. CLI 自己的登录态

- `login`
- `logout`
- `status`
- `refresh`

#### 2. 系统认证方式管理

- `methods`
- `active`
- `activate`
- `config`
- `verify`
- `generate`

如果用户说的是“我怎么登录 CLI / token 怎么来”，走第 1 条。

如果用户说的是“系统支持哪些登录方式 / 切 LDAP / 改 OAuth2 / 校验 LDAP / 生成 JWT 参数认证材料”，走第 2 条。

### 推荐认证方式

自动化 / Agent 场景优先环境变量，但推荐顺序必须和当前 CLI SPEC 保持一致：

```bash
export HBI_HOST="your-everest-instance.com"
```

裸 host 也可以；CLI 会在省略 scheme 时先探测 `https://`，失败后再试 `http://`。也支持带二级路径的 host，例如 `platform.hengshi.org/bi`。

推荐顺序：

1. `HBI_HOST` + `hbi auth login --device-login`
2. `HBI_HOST` + `HBI_CLIENT_ID` / `HBI_CLIENT_SECRET`
3. `HBI_HOST` + `HBI_TOKEN`（仅临时 override，不提供 durable / refresh 保证）

也就是说，`HBI_TOKEN` 不是常规推荐登录方式，更不是 renewable auth 的替代品。

如果还没有 token，再走 `auth login`。`auth login` 会优先读取：

1. 显式 flags `--client-id` / `--client-secret`
2. 环境变量 `HBI_CLIENT_ID` / `HBI_CLIENT_SECRET`
3. 当前工作目录里的 `.env`

人工 / 首次登录：

```bash
HBI_HOST=preview.hengshi.com hbi auth login --device-login
```

自动化 / 已持有 renewable credential：

```bash
HBI_HOST=preview.hengshi.com \
HBI_CLIENT_ID="$HBI_CLIENT_ID" \
HBI_CLIENT_SECRET="$HBI_CLIENT_SECRET" \
hbi auth login
```

只想临时打一条命令，且明确接受 token 过期风险时，才使用：

```bash
HBI_HOST=preview.hengshi.com HBI_TOKEN="<token>" hbi auth status
```

### 指定用户视角执行

当 OAuth client 已配置 `sudo` scope 时，可以对任意命令追加全局 `--as-user`（别名 `--sudo`）：

```bash
hbi app list --area personal-area --root --as-user 1001
hbi app list --area personal-area --root --as-user loginName:trial_user
hbi app list --area personal-area --root --sudo email:demo@example.com
```

规则：

- 裸数字会自动规范化为 `uid:<id>`
- 显式身份格式支持：`uid:<id>`、`loginName:<login_name>`、`email:<email>`、`mobile:<mobile>`
- CLI 会把该值作为 query 参数 `sudo=...` 附加到 API 请求
- 如果当前 OAuth client 没有 `sudo` scope，后端会直接拒绝
- 多租户 sudo 场景如需看目标租户数据，仍要同时传对应命令自己的 `tenantId` / `tenantCode` 语义，而不是只靠 `--as-user`

如果只想先确认 CLI 会用哪组凭据，不要真的发请求，可以先：

```bash
hbi auth login --dry-run
```

需要把凭据写入系统钥匙串时再加 `--interactive`。

### 执行与验证入口：wrapper-first

涉及 repo 执行、验证、CI 对齐时，优先使用仓库 `scripts` 目录里的 wrapper，不要每次重猜裸 `cargo` 命令：

```bash
check-fast
check-ci
check-skills
test-e2e auth::
```

规则：

1. 日常 gate 优先 `scripts` 目录中的 `check-ci`
2. 变更 `skills/**` 或 validator 代码时补跑 `scripts` 目录中的 `check-skills`
3. 真实 auth/runtime 闭环改动补跑最窄的 `scripts` 目录 wrapper `test-e2e auth::...`
4. 只有在调试 wrapper 本身或 Cargo/runner 问题时，才退回裸命令

### 系统认证方式管理

推荐顺序：

```bash
hbi auth methods --output json
hbi auth active --output json
hbi auth config get ldap --output yaml
hbi auth config update ldap --file ldap.yaml --dry-run
hbi auth verify ldap --file ldap.yaml --dry-run
hbi auth activate ldap --enabled true --default-login-page /auth/login --dry-run
hbi auth generate jwt-key --value '{"checkSignAlgorithm":"HS256"}' --dry-run
```

规则：

- 先 `methods` 看 provider 和动态表单，再 `config get/update`
- `activate` 是切当前生效的登录方式，不是普通 `config update`
- `verify ldap` 只校验 LDAP 配置
- `generate jwt-key` 是 `jwt-param` 这条认证方式的材料生成入口
- provider 名必须用帮助页里的稳定值，例如 `ldap` / `cas` / `saml2` / `oauth2` / `jwt-param`

### 配置命令

`hbi config --edit` 当前支持交互式修改：

- API 地址
- CLI 语言（`zh-CN` / `en-US`）

默认语言是 `zh-CN`，也可以通过 `--lang` 或 `HBI_LANG` 覆盖。

### 系统偏好与配置：优先走 `preferences` 模块子树

`preferences` 不再只是一个笼统的“看系统设置”命令。高频稳定入口是：

- `preferences get`
- `preferences about`
- `preferences instances`
- `preferences log-levels`
- `preferences update-log-levels`
- `preferences environment get|update`
- `preferences hbi get|update`
- `preferences security get|update`
- `preferences smtp get|update|verify`
- `preferences home get|update`
- `preferences app-mart-tag get|update`
- `preferences list-sort get|update`
- `preferences skin get|update`
- `preferences css get|update`
- `preferences js get|update`
- `preferences gis get|update`
- `preferences open-dwinfo get|update`

优先使用模块化子树：

```bash
hbi preferences environment get --output json
hbi preferences environment update --value '{"JAVA_HOME":"/tmp/java"}' --dry-run
hbi preferences smtp verify --value '{"enable":false}' --dry-run
hbi preferences skin get --output yaml
```

`get-config` / `set-config` 仍然保留，但它们是按 key 的 raw escape hatch：

```bash
hbi preferences get-config some.key
hbi preferences set-config some.key --value '{"enabled":true}' --dry-run
```

除非用户明确知道配置 key，或者模块化入口没有覆盖，否则不要先跳到 `get-config` / `set-config`。

## 输出与自动化约定

当前全局输出参数是：

```bash
--output table|json|yaml
```

约定：

- 人读输出：默认 `table`
- 自动化提取：优先 `json`
- 需要保留结构且方便审阅时：`yaml`

自动化链路里，优先把“查找 ID”与“修改资源”拆成两步，不要直接假定资源存在。

常见约定：

- CI / 脚本优先 `--output json`
- 高风险写操作先加全局 `--dry-run`
- 需要减少噪音时优先 `--output json` 做结构化提取，不要假设存在全局 `--quiet`
- 删除、授权、发布、下线类操作再确认 `--yes` / `--force`

## 写操作预检协议

- 用户给的是“修一下 / 配一下 / 创建 / 删除 / 跑一下并处理”这类执行型请求时，默认视为允许继续执行；不要额外等一句“去执行”。
- 在第一次写操作前，先用 1-3 句说明：
  - 目标资源与目标结果
  - 准备走哪条命令树，以及为什么不是相邻的 generic `update`
  - 先跑哪些 `--help` / `show` / `list` / `--dry-run`
  - 真正写入后如何验证
- 这是 **speak-then-act**：先说清 preflight，再直接执行；只有用户明确说“先别执行 / 只给方案”时才停在说明阶段。

## 风险升级条件

出现以下任一情况时，先停下说明风险，不要直接写：

- 需要用相邻资源的命令树近似实现目标
- 只能依赖 raw `update --file|--value`，但当前技能没有明确的稳定 authoring contract
- 没有 `--help` / `show` / `--dry-run` 证据能证明当前命令面是对的
- 目标 ID / scope 不唯一，或会影响多资源、共享目录、共享环境
- 属于删除、owner transfer、批量授权、底层来源替换这类高副作用操作
- preflight 输出或后端报错已经说明当前假设不成立

风险升级后的正确动作是：停在 authoritative command tree 收口，解释当前缺口；不要通过修改相邻资源字段来“近似完成”目标。

## 空间与目录概念

`search --help` 和现有源码共同表明以下空间值是稳定入口：

| CLI 值 | 中文含义 |
|---|---|
| `personal-area` | 我的创作 |
| `public-area` | 团队空间 |
| `data-mart` | 数据集市 |
| `app-mart` | 我的空间 |
| `system-portal` | 公共空间 / 衡石大厅 |
| `tenant-system-portal` | 平台空间 |

补充约束：

- `data-app` / 数据包通常创建和检索在 `data-mart`，不要默认放到 `personal-area`

`folder` 在产品里是高频基础概念，不只是一个弱命令组：

- `personal-area` / `public-area` / `data-mart` / `system-portal` 这类空间下，应用、仪表盘、数据集通常都挂在**文件夹树**里。
- `app list --root` / `app list --folder` 本质上也是在复用 folder 结构，而不是另一套独立目录模型。
- 如果用户问的是“根目录 / 子目录 / 团队空间目录树 / 数据集市目录树 / 把应用发布到哪个目录”，要先想到 `folder`。
- 推荐先这样定位目录上下文：

```bash
hbi folder root --area personal-area --output json
hbi folder list --area personal-area --tree --output json
hbi folder list --folder <folder_id> --output json
hbi folder create "销售分析" --parent <folder_id> --dry-run
hbi folder move <folder_id> --parent <new_parent_id> --dry-run
```

规则：

- `folder root --area <area>` 用来拿空间根目录；不要先猜根目录 ID。
- `folder list --tree` 适合看整棵目录结构；`folder list --folder <folder_id>` 适合看某个父目录下的直接子目录。
- `folder create` / `move` 用的都是父目录 ID，不是目录名字。
- `app-mart` 仍然是扁平空间；不要因为 `folder` 很重要，就误以为所有 area 都支持同样的目录树行为。

搜索与应用列表时要注意：

- `personal-area` / `public-area` 是 CLI 规范化空间名；前端英文附近还可能出现 `My Apps` / `My Space` / `Team Apps` / `Public Space`，但不要把它们误当成新的 area。
- `search` 支持递归目录搜索，适合“只知道名字，不知道在哪个应用里”的场景。
- `search` 按名字或标题模糊查找时用 `--query "关键字"`，不要编造 `--name`、`--title` 之类的参数。
- `search --type` 目前稳定值是 `app` / `dashboard` / `dataset`，多个值可逗号分隔。
- `app list` 的空间/目录行为更严格，通常需要 `--area` 配合 `--root` 或 `--folder`。
- `app-mart` 是扁平空间，不要给它错误地加 `--root`、`--folder`、`--recursive`。
- `show` 类命令一律用资源 ID 做位置参数；如果手里只有名字，先 `search` / `list` 拿到 ID，再 `show`。

## 通用执行流程

1. 先执行 `hbi --help` 或 `hbi <命令族> --help`。
2. 如果要写技能、脚本或自动化流程，再看 `hbi <命令族> <子命令> --help`。
3. 写操作先做简短 preflight，再在可用时加 `--dry-run` 验证。
4. 批量或破坏性操作必须确认 `--force` / `--yes` 语义。
5. 需要串联多个资源时，先 `list` / `show` 验证 ID，再继续写操作。

## 常用入口命令

```bash
hbi --help
hbi auth --help
hbi auth methods --output json
hbi auth active --output json
hbi folder root --area personal-area --output json
hbi search --area personal-area --root --recursive --output json
hbi search --area personal-area --folder <folder_id> --recursive --output json
hbi search --area personal-area --root --recursive --query "销售" --output json
hbi preferences environment get --output json
hbi preferences smtp verify --value '{"enable":false}' --dry-run
hbi app show <app_id>
hbi config --edit
```

## 错误处理原则

- 401/403：优先检查认证与权限。
- 404：优先检查 ID、空间、父资源是否匹配。
- 400：通常是参数结构、枚举值或必填项错误。
- 5xx：视为后端或环境问题，保留请求上下文再反馈。

## 禁止事项

- 不要跳过 `hbi <命令族> --help` 就臆测参数名。
- 不要把 CLI 登录态管理（`login/logout/status`）和系统认证方式管理（`methods/active/config/verify/generate`）混成一套命令。
- 不要把 `measure` 和 `metric` 混成同一个概念。
- 不要假设资源 ID 一定存在。
- 不要在已有模块入口时，优先跳到 `preferences get-config/set-config` 猜裸 key。
- 不要编造 `search --name` 这类参数，也不要把资源名字直接传给 `show`。
- 不要对删除、下线、授权变更类操作省略确认环节。
- 不要在已有稳定命令面时，退回相邻资源的 generic `update` 近似实现目标。
