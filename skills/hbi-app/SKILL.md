---
name: hbi-app
description: "应用领域技能。凡是用户提到应用、应用门户/导航、发布、分享、刷新计划、应用参数、公共维度、行级权限、订阅、应用授权、应用空间、数据包替换，或需要围绕 `hbi app` 系列命令工作时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi app --help"
---

# HBI App

> 前置：先读 `hbi-core`，再执行本技能。
>
> 需要写 `connection-replace`、`portal apply`、`locale update`、`rule create/update`、`subscribe create/update` 的 `--file/--value` 载荷时，继续读 `references/payload-contracts.md`。

## 应用领域的中文概念

- `app` = 应用
- `data-app` = 数据包
- `param` = 应用参数
- `dimension` = 公共维度
- `rule` = 行级权限规则
- `subscribe` = 应用通知订阅
- `portal` = 应用门户 / 导航
- `locale` = 应用多语言配置
- `cache-config` = 应用图表缓存配置
- `date-preference` = 应用日期偏好
- `pagination-config` = 应用分页配置
- `runtime-preferences` = 应用运行时偏好（当前主要是“严格权限检查”）
- `dataapp-allocation` = 应用可用数据包分配开关
- `relation` = 可见数据源 / 数据继承关系
- `share` = 分享链接

## 常用命令入口

当前 `hbi app --help` 的常用子命令：

- `list`
- `show`
- `create`
- `duplicate`
- `move`
- `transfer`
- `update`
- `delete`
- `export`
- `import`
- `dataapp-replace`
- `connection-replace`
- `grant`
- `revoke`
- `permissions`
- `publish`
- `unpublish`
- `republish`
- `portal`
- `locale`
- `cache-config`
- `date-preference`
- `pagination-config`
- `runtime-preferences`
- `dataapp-allocation`
- `relation`
- `param`
- `dimension`
- `rule`
- `subscribe`
- `share`

如果需要子命令的精确参数，继续执行：

```bash
hbi app <subcommand> --help
```

## 最常见的应用工作流

### 1. 先定位应用

```bash
hbi app list --area personal-area --root
hbi app list --area public-area --root --output json
hbi app show <app_id>
```

说明：

- `app list` 当前源码里要求明确空间。
- 常见场景下要配合 `--root` 或 `--folder`。
- `app-mart` 是扁平空间，不要给它错误加上目录递归参数。
- 如果目标是 `data-app` / 数据包，优先去 `data-mart` 查；不要默认在 `personal-area`。

如果你只知道应用名字、但不知道它在哪个目录，先走 `search`，不要硬用 `app list` 猜目录：

```bash
hbi search --area personal-area --root --recursive --type app --query "销售" --output json
hbi search --area personal-area --folder <folder_id> --recursive --type app --query "销售" --output json
hbi app show <app_id>
```

- `app list` 适合“已知 area，且已知根目录/父目录”的场景
- `search` 更适合“只知道名字，不知道挂在哪”的场景
- 对 `app-mart`，不要加 `--root`、`--folder`、`--recursive`

### 2. 创建应用

```bash
hbi app create "销售分析" \
  --app-type analytic-app \
  --area personal-area \
  --description "月度销售分析"
```

创建应用时先关注：

- 名称是位置参数 `name`
- 支持 `--description`
- 支持 `--app-type`
- 支持 `--area`
- 支持 `--folder`
- `analytic-app` / `query-app` / `report-app` 通常放在 `personal-area`
- `data-app` / 数据包应创建在 `data-mart`，例如：

```bash
hbi app create "销售数据准备" \
  --app-type data-app \
  --area data-mart
```

### 3. 更新、复制、删除、导入导出

```bash
hbi app update <app_id> --name "新的应用名称"
hbi app move <app_id> --folder <folder_id>
hbi app transfer <app_id> --user <user_id>
hbi app duplicate <app_id> --name "新的应用副本" --folder <folder_id>
hbi app delete <app_id> --force
hbi app export <app_id> --file app-export.hstpl
hbi app import <app_id> template.json --copy
hbi app import-template template.hstpl --area personal-area
```

- `app move` 走应用 update 同款端点，通过 `folderId` 移动现有应用；这和 `duplicate` 创建副本不是一回事
- 需要保留原授权配置时默认沿用前端行为；如需按目标目录继承授权，可显式传 `--keep-auth false`
- `app transfer` 走系统资源转移端点，改的是应用 `Creator` / 所有者，不是访问权限；当前以 `hbi app transfer <app_id> --user <user_id>` 为稳定命令面
- `app import` 是**覆盖现有应用**：它需要现成的 `<app_id>`，底层走 `/apps/{id}/overwrite`
- `app import-template` 是**从模板新建应用/数据包**：它把 `.json/.hstpl` 导入到目标目录；如果不传 `--folder`，就落到 `--area` 的根目录
- 当前 `app import-template` 主要对齐前端创作区 / 数据集市里的目录级“导入模板”入口，目标空间优先用 `personal-area`、`public-area`、`data-mart`

### 4. 模板迁移后的高频替换

```bash
hbi app dataapp-replace <app_id> --list
hbi app dataapp-replace <app_id> --replace <source_dataapp_id>:<target_dataapp_id>
hbi app connection-replace <app_id> --list
hbi app connection-replace <app_id> --replace <source_connection_id>:<target_connection_id>
hbi app connection-replace <app_id> --file connection-replace.yaml
```

- `dataapp-replace` 适合整包迁移后把应用里引用的数据包批量改到目标环境的数据包。
- `connection-replace` 适合把应用里所有落在某个 connection / schema path 上的数据集统一切到新环境。
- 如果只想替换**某一个数据集**的底层来源，不要停留在 `app`，切到 `hbi-data` 的 `dataset replace`。

### 5. 门户导航

```bash
hbi app portal --app <app_id> show --output yaml
hbi app portal --app <app_id> apply --file portal.yaml
hbi app portal --app <app_id> delete --force
```

说明：

- 当前门户按单应用单 portal 处理。
- `show` 输出可直接作为 `apply --file` 的编辑起点。
- `apply` 走前端同款 portal CRUD 端点，不要用 `app update` 猜测写入位置。
- 如果 `app show <id>` 里看到了 `portals`，把它当作**只读详情**；真正写回仍然走 `app portal apply`。
- 从空 portal 起手时，优先参考 `references/payload-contracts.md` 里的最小 skeleton 与 menu 形状约束；不要手写 `imagesList`、自动生成的 `uid`，也不要把 `hide` 之类 runtime 临时菜单当成 authoring 必填字段。
- file authoring 时优先围绕 `pc` / `mobile`、`menus`、`menuIndex`、`position`、`theme`、`title`、`subTitle`、`logo`、`showLogo`、`showAppPath` 这些稳定字段；不要手写 `hide` 之类 runtime 临时菜单，也不要把 `imagesList` 当成必填 authoring 字段。

### 5. 多语言配置

```bash
hbi app locale --app <app_id> show --output json
hbi app locale --app <app_id> export --output json
hbi app locale --app <app_id> update --locales-enabled true
hbi app locale --app <app_id> update --file locale-config.yaml
```

- `app locale` 是一等命令面，不要继续通过 `app update` 猜测 `localeConfig` 的落点。
- `export` 会像前端多语言编辑页一样，先拉全量 app detail（dashboard/filter/portal 等）并预构建 bare `localesMap` JSON，适合作为 `export -> edit -> update --file ...` 的起点。
- 推荐 workflow：先 `hbi app locale --app <app_id> export --output json` 导出 bare `localesMap`，修改翻译 JSON 后，再用 `hbi app locale --app <app_id> update --file ...` 写回；如果目标应用还没启用多语言，可在同一次 `update` 里补 `--locales-enabled true`。
- `update --file/--value` 接受 `localeConfig` object，也接受直接传 `localesMap` 的前端翻译对象；如果输入的是 `app show --output json` 这类带顶层 `localeConfig` 的对象，CLI 也会抽取并写回正确字段。
- 只想快速开关多语言时，优先用 `--locales-enabled true|false`。

### 6. 图表缓存配置

```bash
hbi app cache-config --app <app_id> show --output json
hbi app cache-config --app <app_id> update --customized true --seconds 600
hbi app cache-config --app <app_id> update --customized false
```

- `app cache-config` 走前端同款专用端点 `/apps/{id}/cache-interval`，不要退回 `app update` 猜 `options` patch。
- `show` 会输出前端当前真正关心的两个字段：
  - `useAppCustomCacheInterval`
  - `resultCacheInterval`
- `update --customized false` 表示关闭应用级自定义缓存时间，恢复后端默认缓存周期；此时不要再同时传 `--seconds`。

### 7. 日期偏好

```bash
hbi app date-preference --app <app_id> show --output json
hbi app date-preference --app <app_id> update --week-start-day 0
```

- 当前 CLI 先暴露前端设置页里最稳定的一段：`options.dateConfig.weekStartDay`。
- `--week-start-day` 取值是 `0..6`：
- `0 = 周日`
- `1 = 周一`
- …
- `6 = 周六`
- 这是一个 typed surface，但底层仍走前端同款 `PUT /apps/{id}` + `options.dateConfig` merge；不要为了改周起始日去手写整段 raw app update。

### 8. 分页配置

```bash
hbi app pagination-config --app <app_id> show --output yaml
hbi app pagination-config --app <app_id> update --file pagination.yaml
```

- `app pagination-config` 处理的是整段 `options.pagination`，不是几个零碎 flags。
- `show` 会输出前端对齐的 authoring 视图：带上分页默认值、`themeCustomize` 默认样式，以及当前可用的 `applyToDashboards` 结果。
- 推荐 workflow：先 `show` 导出当前分页配置，编辑后再 `update --file ...` 写回。
- `update --file/--value` 接受 bare `pagination` object，也接受带 `pagination` / `options.pagination` wrapper 的对象；CLI 会写回正确的 `options.pagination`。
- `autoPaging` 当前也归在这一条下面，按前端同款 shape 写 `enable` / `mode` / `interval` / `unit`，不要退回 `app update` 手写 raw patch。

### 9. 严格权限检查（runtime-preferences）

```bash
hbi app runtime-preferences --app <app_id> show --output json
hbi app runtime-preferences --app <app_id> update --strict-validate true
```

- 当前这条命令对齐前端设置页里的 **“严格权限检查”** 开关。
- 前端原始说明是：
  - **开启**：用户通过其他数据包或应用访问数据集时，必须拥有该数据集的至少一行权限，或拥有本数据包整体的访问权限（查看 / 编辑 / 管理）
  - **关闭**：允许用户通过其他数据包或应用访问数据集
- 该开关当前只对齐 **data-mart / data-app** 场景；前端普通 analytic/query/report app 设置页没有这项。
- `show` 当前输出的 JSON 键仍是 `enableRuleStrictValidate`；把它理解成前端文案 **“严格权限检查”** 即可。
- `update --strict-validate true|false` 底层走前端同款 `PUT /apps/{id}`，但只 merge 这一个稳定字段；不要为这项退回手写整段 `app update`.
- 全屏自动翻页不要误归到这里；那部分前端真实落点是 `options.pagination.autoPaging`，应继续走 `app pagination-config`。

### 10. 可用数据包分配

```bash
hbi app dataapp-allocation --app <app_id> show --output json
hbi app dataapp-allocation --app <app_id> update --enabled true
```

- 当前这条命令只覆盖作者区应用设置页里的 **“可用数据包”开关**，即 `options.enableDataAppAllocate`。
- `show` 同时返回当前后端认定的：
  - `enableDataAppAllocate`
  - `availableDataApps`
- 适用范围是 **authoring app**（如 personal/public 下的 analytic/query/report app）；`data-mart` 里的 data-app 源侧继承管理不走这条命令。
- `update --enabled true|false` 走前端同款 `/apps/{id}/available-dataapp`，并保留当前 `availableDataApps` 列表；不要把它误当成 data-use / data-extend relation 的通用增删改入口。
- 可以把它理解成“作者区应用是否启用按清单限制可用数据包”的总开关；真正管理某个 app 与某个数据包之间的 `data_use` / `data_extend` 关系，继续走 `app relation`。

### 11. 可见数据源 / 数据继承关系（relation）

```bash
hbi app relation --app <target_app_id> list --type data-use --output json
hbi app relation --app <target_app_id> add --type data-extend --source-app <data_app_id>
hbi app relation --app <target_app_id> inheritance --source-app <data_app_id> update --inherit-all false --inherit-dataset 101 --inherit-dataset 102
hbi app relation --app <source_data_app_id> extend-approval update --enabled true
hbi app relation --app <source_data_app_id> review --target-app <target_app_id> update --status approved --keep-dataset-acl false
```

- 这条命令覆盖的是前端两块稳定写面，不要再退回 `app update` / raw patch：
  - **目标应用视角（authoring app）**
    - 设置页 **“可见数据源设置”** 对应 `list/add/delete`
    - 数据集页 **“数据继承管理”** 对应 `inheritance show/update`
  - **源数据包视角（data-mart / data-app）**
    - 设置页 **“继承管理”** 与 **“启用数据继承审核”** 对应 `extend-approval show/update`
    - 对具体目标应用的审批 / ACL 保留对应 `review show/update`
- 可以把这块理解成 **“应用与数据包之间的关系治理层”**：
  - 它控制的是“这个应用能看到/使用/继承哪个数据包，以及源数据包是否需要审核”
  - 它**不是** generic `app update`
  - 它也**不是** dataset 本体编辑
- 先分清三个相邻概念：
  - `dataapp-allocation`：作者区应用的 **“可用数据包”总开关**
  - `data_use`：目标应用把某个数据包当成 **可见 / 可用的数据源**
  - `data_extend`：目标应用把某个数据包当成 **可继承扩展的数据源**
- 前端对 **“可见数据源设置”** 的说明是：**未启用时，全部数据源可见；启用时，可见数据源设置生效。**
- 前端对 **“数据继承管理”** 的说明是：应用可以在继承的公共数据基础上进行 **新增字段、新增指标、扩展关联模型** 等操作；所以 `data_extend` 不只是“能看到”，而是“能基于这个数据包继续扩展建模”。
- `--type` 的 CLI 取值是 `data-use` / `data-extend`；输出里的后端枚举仍会显示成 `data_use` / `data_extend`。
- `inheritance` 是 `data_extend` relation 上的细粒度配置：
  - `inheritAll=true` 表示继承全部数据集
  - `inheritAll=false + inheritIds=[...]` 表示只继承指定数据集
- `inheritance update` 只改 relation-level 的 `relationOptions.inheritAll / inheritIds`，不要误写成数据集 update。
- 前端对 **“启用数据继承审核”** 的说明是：**未启用时，将关闭数据继承审核流程，申请人添加数据包后自动允许继承。**
- `review update` 当前只覆盖后端稳定可写字段：`status`（`pending|approved`）与 `keepDatasetAcl`。
- `keepDatasetAcl` 可以理解成：源数据包在允许继承时，是否继续保留源侧数据集 ACL 的约束。
- 如果当前应用是普通 analytic/query/report app，就走目标应用视角的 `list/add/delete/inheritance`；如果当前应用是 data-mart 下的数据包，就走源数据包视角的 `extend-approval/review`。

## 应用权限与发布

### 应用内授权

```bash
hbi app permissions <app_id>
hbi app grant <app_id> --user <user_id> --permission edit
hbi app revoke <app_id> --group <group_id>
```

### 所有者转让

```bash
hbi app transfer <app_id> --user <user_id>
```

- `grant` / `revoke` 改的是访问权限，不会改 `Creator`
- `transfer` 改的是资源所有者，走后台统一资源转移能力，要求管理员权限
- 当前不要把它答成 `authorize grant` 或 `app grant`

### 发布与下架

```bash
hbi app publish <app_id> --folder <folder_id>
hbi app publish <app_id> --folder <folder_id> --default-view portal
hbi app unpublish <app_id> --force
hbi app republish <app_id>
hbi app republish <app_id> --description "Updated Q2 Report"
hbi app republish <app_id> --default-view portal --cover ./new-cover.png
hbi app republish <app_id> --dry-run
```

### 发布与分享不要混用

```bash
hbi app publish <app_id> --folder <folder_id>
hbi app share enable <app_id>
hbi app share link <app_id>
hbi app share update <share_hash> --password-required true --password "<password>"
hbi app share verify-password <share_hash> --password "<password>"
hbi app share refresh <app_id>
```

- `publish` / `unpublish` 管的是“上架到发布空间”
- `publish --default-view` 当前稳定取值是 `dashboard | portal`
- 不传 `--default-view` 时，CLI 会优先保留现有 `options.publishConfig.defaultView`；如果应用还没有发布配置，则默认回到 `dashboard`
- `share` 管的是“分享链接本身的开关、密码、HMAC、签名”
- `share enable` / `disable` / `refresh` 用的是 **app id**
- `share link` 用的是 **app id**：它会从 app 详情里的 `share` 对象解析当前公开链接；如果应用还没开启公开分享，会直接报错
- `share update` / `verify-password` 用的是 **share hash**
- `share signature` 走的是 `--app-hash`，不是普通 app id
- 当前不要编造 `share get`：后端管理态没有稳定的 `GET /shares/{hash}` surface；如果只是想拿可分享路径，走 `share link`

### 应用刷新计划

```bash
hbi app refresh-schedule <app_id> create \
  --cron "0 0 2 * * *" \
  --enabled \
  --notify-users-on-failure \
  --notify-user 1001 \
  --notify-user 1002
```

- 当前这是应用级 `APP_REFRESH` 的**首次创建**入口，不要一上来就误转成通用 `scheduler`
- `create` 当前是第一优先子命令
- `--cron` 支持 5 段或 6 段，CLI 会归一成前端对齐的 6 段格式
- 失败通知要配 `--notify-users-on-failure` 和至少一个 `--notify-user`
- 如果计划已经建好，后续需要统一看 `schedule_id` / `context` / `logs` 或改依赖、失败通知，再切到 `hbi-scheduler`

### 分享链接

分享相关的精确子命令在 `app share --help` 中确认。使用本技能时要记住：

- 分享是应用级能力
- 不要复用旧文档里的 `hash` 方案去推断新命令行为

## 应用下的扩展资源

以下命令族是常见扩展入口，参数要按帮助页继续下钻：

- `app param`
- `app portal`
- `app locale`
- `app relation`
- `app dimension`
- `app rule`
- `app subscribe`
- `app share`
- `app refresh-schedule`

推荐模式：

```bash
hbi app param --help
hbi app portal --help
hbi app locale --help
hbi app relation --help
hbi app dimension --help
hbi app rule --help
hbi app subscribe --help
hbi app share --help
hbi app refresh-schedule --help
```

常见定位键差异：

| 命令族 | 常见定位键 | 备注 |
|---|---|---|
| `app param` | 参数 ID | `show/update/delete` 常走 ID |
| `app dimension` | 维度名 | `get/update/delete` 常走 name，不是 ID |
| `app rule` | 规则 ID | `show/update/delete` 常走 ID |
| `app subscribe` | 订阅 ID | `show/update/delete` 常走 ID |

- 这些子命令大多都需要先给 `--app <app_id>`
- `app dimension create/update` 常见字段写法是 `--field <dataset_id>:<field_name>`
- `app rule create/update` 的快捷 flags 主要覆盖 `name/type/users/organizations/orgs`
- 真正的行级/列级过滤体要优先走 `--file` / `--value`，写稳定持久化字段 `dataFilters` 与 `options.filterCategory`
- 不要把前端编辑态的 `rootCondition` 当成稳定写回合同；真正保存的是 `dataFilters`
- 当规则带有 `dataFilters` 时，后端会联动相关 dataset 的 `dataControl`；不要再额外用 `dataset update` 手工开关
- `app rule` 的 authoritative 写入口只有：
  - `app rule enable|disable`
  - typed `create-row|update-row`
  - typed `create-column|update-column`
  - raw `create/update --file|--value`（仅在需要直接控制完整 `dataFilters` / `excludeColumns` 时）
- 如果 typed surface 不够，或后端对非空 `dataFilters` 返回 contract error，先停下说明当前 `app rule` / backend gap；不要退回 `dataset update`、`app update` 或 `permission app-rules` 去近似实现。

行级/列级权限规则的 agent-first 写法优先这样：

```bash
hbi app rule --app <app_id> enable

hbi app rule --app <app_id> create-row "门店行权限" \
  --users 1001 \
  --condition "<dataset_id>:{store} = 'Downtown'"

hbi app rule --app <app_id> create-row "门店行权限" \
  --users 1001 \
  --formula "<dataset_id>:isnotnull({store})"

hbi app rule --app <app_id> create-column "隐藏敏感列" \
  --users 1001 \
  --exclude-column <dataset_id>:director \
  --exclude-column <dataset_id>:phone
```

规则：

- `enable` / `disable`：
  - 这是应用级总开关，实际写的是 app `options.enableAppRule`
  - 它控制前端“行级权限”页面顶部的开关，不是单条 rule 的启停字段
- `create-row` / `update-row`：
  - `--condition` 是简单比较语法，当前稳定子集是 `{field} = value`、`!=`、`>`、`>=`、`<`、`<=`、`like`、`unlike`、`is null`、`is not null`
  - `--formula` 直接写 HE 公式；复杂逻辑优先走这个
  - `--condition` 和 `--formula` 不要混用；它们分别映射到 `options.filterCategory = SIMPLE | FORMULA`
  - `--root-condition and|or` 控制同一 dataset 下多条条件的组合关系
  - `--condition` / `--formula` 的值都写成 `DATASET_ID:EXPR`
- `create-column` / `update-column`：
  - `--exclude-column` 写成 `DATASET_ID:FIELD_NAME`
  - CLI 会先取 dataset schema，再生成前端同款 `excludeColumns` 字段对象；不要手写整段列对象
- 需要多 dataset、多条条件时，继续重复传 `--condition` / `--formula` / `--exclude-column`
- 只有超出这层 typed surface、需要直接控制完整 `dataFilters` JSON 时，才退回 `create/update --file|--value`

## 与其他技能的边界

- 需要在应用里创建仪表盘：转 `hbi-dashboard`
- 需要在应用里查数据集/数据模型：转 `hbi-data`
- 需要做更细的权限体系：转 `hbi-permission`
- 需要治理已存在的 app refresh schedule：转 `hbi-scheduler`

## 禁止事项

- 不要把“应用”和“文件夹”混为一谈。
- 不要在未确认空间与目录的情况下直接创建应用。
- 不要在未确认目标用户/用户组的情况下直接授权。
- 不要发布应用时省略 `--folder`。
- 不要在 `app rule` 失败或未知时，退回相邻资源的 generic update 近似实现规则效果。
