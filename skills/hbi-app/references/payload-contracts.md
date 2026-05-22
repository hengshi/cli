# App Payload Contracts

在以下场景继续读取本参考：

- 需要给 `app connection-replace`、`app portal apply`、`app locale update`、`app rule create/update`、`app subscribe create/update` 写 `--file/--value`
- 需要判断某个 payload 是 array、object，还是“show 输出改完即可回灌”

## 通用规则

- `connection-replace` 的 payload 是 **array**
- `portal apply`、`locale update`、`rule create/update`、`subscribe create/update` 的 payload 都是 **object**
- `rule` / `subscribe` 这两类命令的 CLI flags 会和 payload 一起 merge；flags 的优先级更高

## `app connection-replace`

`--file/--value` 必须是数组，每项对应一条替换规则：

```yaml
- current: 12
  replace: 144
  replaceSchema:
    qa.coffee_sales: qa.coffee_sales_copy
```

字段说明：

| 字段 | 含义 |
|---|---|
| `current` | 当前 connection id |
| `replace` | 目标 connection id |
| `replaceSchema` | 可选路径映射，key/val 都是字符串 |

这条 payload 没有 wrapper；直接传数组。

## `app locale update`

CLI 当前接受三种等价输入：

### 1. 完整 wrapper

```yaml
localeConfig:
  localesEnabled: true
  defaultLocale: en-US
  localesMap:
    en-US:
      appTitle: Demo
    zh-CN:
      appTitle: 演示应用
```

### 2. 直接传 localeConfig object

```yaml
localesEnabled: true
defaultLocale: en-US
localesMap:
  en-US:
    appTitle: Demo
```

### 3. 直接传 `localesMap` 简写

```yaml
en-US:
  appTitle: Demo
zh-CN:
  appTitle: 演示应用
```

第三种写法会被 CLI 自动包装成：

```yaml
localesMap:
  ...
```

最终写回时，CLI 总是走顶层：

```yaml
localeConfig:
  ...
```

`localesMap` 每个 locale 下的具体 key 不是 CLI 静态枚举；最稳妥的来源是：

```bash
hbi app locale --app <app_id> show --output yaml
```

## `app portal apply`

`app portal apply` 接受两种形态：

1. `AppPortal` wrapper

```yaml
options:
  pc:
    menus: []
  mobile:
    menus: []
```

2. 裸 `PortalConfig`

```yaml
pc:
  menus: []
mobile:
  menus: []
```

### `PortalConfig` 的稳定顶层

| 字段 | 说明 |
|---|---|
| `imagesList` | 关联图片 id 列表；CLI 会从 `pc.logo` 与 menu `icon` 自动回填 |
| `pc` | 桌面门户配置 |
| `mobile` | 移动门户配置 |

### `pc` / `mobile` 的高频字段

| 字段 | 说明 |
|---|---|
| `menus[]` | 菜单树 |
| `menuIndex` | 默认高亮菜单 |
| `position` | `pc` 常见 `top`；`mobile` 常见 `bottom` |
| `theme` | 门户主题 |
| `title` | 主标题 |
| `subTitle` | 副标题（仅 `pc`） |
| `showLogo` | 仅 `pc` |
| `logo` | 仅 `pc`，通常是图片 id |
| `showAppPath` | 仅 `pc` |

### `menus[]` 的稳定字段

| 字段 | 说明 |
|---|---|
| `uid` | 菜单 uid；缺失时 CLI 自动生成 |
| `pid` | 父菜单 uid |
| `label` | 菜单名 |
| `targetDashboard` | dashboard 菜单目标 |
| `targetUrl` | 外链目标 |
| `targetUrlName` | 外链标题 |
| `openAs` | `_self` / `_blank` 等 |
| `icon` | 图标，常见是数字图片 id |
| `showLabel` / `showIcon` | 菜单显示控制 |
| `showHeader` / `showHeaderTitle` / `showHeaderActions` | dashboard 菜单 header 行为 |
| `isDashboard` / `isLink` | 菜单类型标记 |
| `hide` | 临时隐藏；CLI apply 前会把 `hide: true` 菜单清掉 |
| `children[]` | 子菜单 |

### 最小示例

```yaml
pc:
  menus:
    - label: Overview
      targetDashboard: 11
    - label: Docs
      targetUrl: https://www.hengshi.com
      openAs: _blank
mobile:
  menus:
    - label: Overview
      targetDashboard: 11
```

CLI 的 save-side normalize 还会自动补：

- `pc.position = top`
- `mobile.position = bottom`
- 默认 `theme.light/dark`
- 默认 `title` / `subTitle`
- dashboard/link/group 菜单的 `showLabel` / `showIcon` / `openAs` / header flags

## `app rule create/update`

`rule create/update` 的 raw payload 是 object。当前稳定的顶层字段是：

```yaml
name: Regional access
type: ROW
users:
  - id: 1
organizations: []
orgs: []
tenants: []
dataFilters:
  - datasetId: 3
    filter:
      ruleType: ROW
      excludeColumns: []
      where:
        - kind: formula
          op: "{region} = 'East'"
options:
  filterCategory: FORMULA
```

### 稳定字段

| 字段 | 说明 |
|---|---|
| `name` | 规则名 |
| `type` | `ROW` 或 `COLUMN` |
| `users` / `organizations` / `orgs` / `tenants` | principal 绑定数组，元素是 `{ id, name? }` |
| `dataFilters[]` | 真正的行/列权限主体 |
| `options.filterCategory` | `SIMPLE` 或 `FORMULA` |

### `dataFilters[]`

每项固定长这样：

```yaml
- datasetId: 3
  filter:
    ruleType: ROW | COLUMN
    where: []
    excludeColumns: []
```

说明：

- 行规则主要写 `where`
- 列规则主要写 `excludeColumns`
- `excludeColumns` 里的元素应该是带 `datasetId` 的真实 schema field object；如果你没有现成 runtime，优先用 typed `create-column/update-column`，不要手搓

### merge 规则

- `create/update` 时，CLI flags `name` / `type` / `users` / `organizations` / `orgs` 会覆盖 payload 里的同名内容
- `update` 会先读取当前规则，再 merge payload，避免把已有 `dataFilters` / principal 绑定冲掉

如果用户只是想写常见 row/column 规则，优先走：

- `app rule create-row|update-row`
- `app rule create-column|update-column`

raw payload 更适合“已经有前端稳定 body / `show --output json`”的场景。

## `app subscribe create/update`

`subscribe create/update` 的 raw payload 是 object，顶层字段当前稳定为：

```yaml
title: Weekly report
email:
  enabled: true
  emailAddressList:
    - ops@example.com
  emailSubject: Weekly report
  emailContentBody: Attached dashboard export.
webhook:
  enabled: false
wecom:
  enabled: false
feishu:
  enabled: false
dingtalk:
  enabled: false
```

### 顶层 channel

| 字段 | 说明 |
|---|---|
| `title` | 订阅标题 |
| `email` | 邮件配置 |
| `webhook` | Webhook 配置 |
| `wecom` | 企业微信配置 |
| `feishu` | 飞书配置 |
| `dingtalk` | 钉钉配置 |

### `email`

高频字段：

- `enabled`
- `receiverList`
- `emailAddressList`
- `dashboardList`
- `buildMessageAsOwner`
- `bodyWithImage`
- `attachmentType`
- `compressAttachment`
- `includeChartNotes`
- `emailSubject`
- `defaultEmailSubject`
- `emailContentBody`
- `defaultEmailContentBody`
- `bodyWithDashboardUrl`
- `emailBodyCustomized`

### `webhook`

高频字段：

- `enabled`
- `url`
- `method`
- `headers[]`
- `requestBody`
- `dashboardList`
- `buildMessageAsOwner`
- `bodyWithDashboardUrl`

`headers[]` 每项是：

```yaml
- headerName: Authorization
  headerValue: Bearer xxx
  headerDesc: optional
```

### `wecom` / `feishu` / `dingtalk`

这三类共用同一套 shape：

- `enabled`
- `targets`
- `receiverList`
- `defaultSubject`
- `subject`
- `content`
- `defaultContent`
- `bodyCustomized`
- `buildMessageAsOwner`
- `bodyWithImage`
- `bodyWithDashboardUrl`
- `dashboardList`
- `includeChartNotes`

### merge 规则

- `create/update` 时，CLI flags 会在 raw payload 之上叠加最小 channel overlay
- `update` 会先读当前订阅，再 merge 这次修改，所以 rename-only update 不会把旧 channel 配置清空

如果没有明确要覆盖 richer channel 字段，优先用 CLI flags；如果已经有稳定 payload，则从：

```bash
hbi app subscribe --app <app_id> show <record_id> --output yaml
```

导出后再编辑最稳。
