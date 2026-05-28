# App Payload Contracts

在以下场景继续读取本参考：

- 需要给 `app connection-replace`、`app portal apply`、`app locale update`、`app rule create/update`、`app subscribe create/update` 写 `--file/--value`
- 需要判断某个 payload 是 array、object，还是“show 输出改完即可回灌”

## 功能点速查

| 用户说法 / 中文术语 | 读哪一节 | 稳定 payload path / shape |
|---|---|---|
| 连接替换 / 换连接 / 库表路径映射 | `app connection-replace` | `[].current` / `[].replace` / `[].replaceSchema` |
| 多语言开关 / 默认语言 / 翻译词条 | `app locale update` | `localeConfig.localesEnabled` / `localeConfig.defaultLocale` / `localeConfig.localesMap` |
| 门户菜单 / 导航 / 顶部菜单 / 底部菜单 / 标题 / Logo / 门户主题 | `app portal apply` | `pc.*` / `mobile.*` / `menus[]` |
| 行级权限 / 列级权限 / 规则作用对象 / SIMPLE vs FORMULA | `app rule create/update` | `dataFilters[].filter.where` / `dataFilters[].filter.excludeColumns` / `users` / `organizations` / `orgs` / `tenants` / `options.filterCategory` |
| 订阅渠道 / 邮件订阅 / Webhook / 企微 / 飞书 / 钉钉 | `app subscribe create/update` | `email` / `webhook` / `wecom` / `feishu` / `dingtalk` |

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

功能点速查：

| 功能点 / 用户说法 | payload path | 说明 |
|---|---|---|
| 当前连接 | `[].current` | 当前环境里被替换掉的 connection id |
| 替换目标连接 | `[].replace` | 目标环境 connection id |
| schema / 路径映射 | `[].replaceSchema` | `源路径 -> 目标路径` 的字符串映射 |

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

功能点速查：

| 功能点 / 用户说法 | payload path | 说明 |
|---|---|---|
| 启用 / 关闭多语言 | `localeConfig.localesEnabled` | 对应前端多语言总开关 |
| 默认语言 | `localeConfig.defaultLocale` | 默认展示 locale |
| 翻译词条 / 文案映射 | `localeConfig.localesMap.<locale>.*` | 具体 key 最稳从 `locale show/export` 导出 |

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

功能点速查：

| 功能点 / 用户说法 | payload path | 说明 |
|---|---|---|
| 桌面门户菜单 / 顶部导航 | `pc.menus[]` | 桌面菜单树 |
| 移动门户菜单 / 底部导航 | `mobile.menus[]` | 移动端菜单树 |
| 默认高亮菜单 | `pc.menuIndex` / `mobile.menuIndex` | 默认选中的菜单索引 |
| 主标题 / 副标题 | `pc.title` / `pc.subTitle` | `mobile` 常见只关注主标题 |
| Logo / 是否显示 Logo | `pc.logo` / `pc.showLogo` | `imagesList` 会从这里自动回填 |
| 门户主题 | `pc.theme` / `mobile.theme` | 门户整体主题设置 |
| 仪表盘菜单目标 | `menus[].targetDashboard` | 跳到某个 dashboard |
| 外链菜单目标 | `menus[].targetUrl` / `menus[].targetUrlName` / `menus[].openAs` | 跳外部链接 |

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

### 空 portal 起手时的 authoring 建议

推荐 workflow：

1. 先跑 `hbi app portal --app <app_id> show --output yaml`
2. 如果返回 `null` / 没有 portal，就从上面的最小示例起手
3. 只改稳定 authoring 字段，再 `apply --file ...`

菜单项优先只写 3 种稳定形状之一，不要混搭：

1. dashboard 菜单：`label` + `targetDashboard`
2. link 菜单：`label` + `targetUrl`（可选 `openAs` / `targetUrlName`）
3. group 菜单：`label` + `children`

补充规则：

- `children` 嵌套树优先于手写 `pid`；只有要保留既有扁平 uid/pid 结构时才显式写 `pid`
- `imagesList` 不需要手写；CLI 会从 `pc.logo` 与 menu `icon` 自动回填
- `uid` 缺失时 CLI 自动生成；除非你要稳定引用既有菜单，否则不要手写
- `hide: true` 的菜单会在 apply 前被清掉；不要把它当成“保留但暂时隐藏”的 durable authoring 形状

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

功能点速查：

| 功能点 / 用户说法 | payload path | 说明 |
|---|---|---|
| 规则名称 | `name` | 规则标题 |
| 行级权限条件 | `dataFilters[].filter.where` | 行规则主体 |
| 列级隐藏列 | `dataFilters[].filter.excludeColumns` | 列规则主体 |
| 作用对象（用户/组织/租户） | `users` / `organizations` / `orgs` / `tenants` | 绑定的 principal 列表 |
| SIMPLE / FORMULA 模式 | `options.filterCategory` | 对应前端条件模式 |
| 规则类型（行/列） | `type` + `dataFilters[].filter.ruleType` | 顶层和 filter 内都应一致 |

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

功能点速查：

| 功能点 / 用户说法 | payload path | 说明 |
|---|---|---|
| 订阅标题 | `title` | 订阅记录名称 |
| 邮件订阅 | `email.*` | 收件人、主题、正文、附件等 |
| Webhook 通知 | `webhook.*` | URL、method、headers、requestBody |
| 企业微信通知 | `wecom.*` | 群 / 接收对象 / 文案等 |
| 飞书通知 | `feishu.*` | 群 / 接收对象 / 文案等 |
| 钉钉通知 | `dingtalk.*` | 群 / 接收对象 / 文案等 |

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
