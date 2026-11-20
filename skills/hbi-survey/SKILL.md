---
name: hbi-survey
description: "数据填报领域技能。凡是用户提到数据填报、表单、survey、调查问卷、收集数据、填报模板、单选/多选控件，或需要围绕 `hbi survey` 创建、更新、读取填报模板与填报数据时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi survey --help"
---

# HBI Survey

> 路由：问数/取数/出图（含仪表盘内提问）先读 `hbi-chatbi`；authoring session 中的删除、授权、调度、执行类变更先读 `hbi-data-agent-authoring`，本技能只负责读取与可恢复内容。

> 前置：先读 `hbi-core`。需要确认数据连接、库表路径或字段类型时，参考 `hbi-data`。

## 资源边界

- `survey` 是独立的数据填报资源：一个模板 = 一组控件 + 一张落库表。
- 模板绑定 `connectionId`、`tablePath`、`table`；开启填报（`status=OPEN`）时这些字段必须可用，且表不能已存在。
- 所有 survey API 都要求 `DATA_ADMIN` 角色；创建/更新还需要目标连接的写权限。普通成员调用 `list` / `show` 也会收到 403。
- 控件公共字段是 `uuid`、`title`、`fieldName`、`required`、`options`；`richText` 只需要 `uuid`，不落库。
- `fieldName` 是落库列名，只允许 `[a-zA-Z0-9_]+`，且不能等于 `SurveyUtils.HS_COLUMN_NAME_SET` 里的系统列名（`hs_row_id`、`hs_user_id` 等），不是禁止所有 `hs_*` 前缀。
- `uuid` 在同一模板内唯一，是填报数据提交时的键。
- 数据按控件落成一列；修改控件会触发加列/删列/改列，不是只改前端展示。
- 删除模板只删除模板元数据，**落库表和已提交数据会保留**；需要清理数据时单独处理表。

## 支持的主要控件

| inputType | 用途 | options 关键字段 |
| --- | --- | --- |
| `singleLineText` | 单行文本 | `placeholder`、`maxLength` |
| `multilineText` | 多行文本 | `placeholder`、`maxLength` |
| `richText` | 富文本说明，不落库 | `content` |
| `numberInput` | 数字 | `placeholder`、`minValue`、`maxValue`、`onlyInteger` |
| `dateInput` | 日期 | `enableTime`、`nowPlaceholder` |
| `emailInput` | 邮箱 | `placeholder` |
| `phoneInput` | 手机号 | `placeholder` |
| `telephoneInput` | 电话号码 | `placeholder` |
| `radioInput` | 单选 | `items`、`styleType`（`radio` / `select`） |
| `checkboxInput` | 多选 | `items`、`styleType`（`checkbox` / `select`）、`layout`（`vertical` / `horizontal`） |

多选规则：

- `options.items` 必须是非空、无重复、无首尾空格的字符串数组；选项文案可以包含英文逗号。
- 提交时值是一个字符串数组，例如 `["研发", "运维"]`，也接受 JSON 数组字符串；英文逗号拼接的旧格式不再接受。
- 服务端按 `items` 顺序、去重后以 JSON 数组字符串落库，例如 `["研发","运维"]`；不在 `items` 中的值按提交顺序追加。
- 空数组/空字符串落为 `NULL`；必填控件至少选一项。
- 单个选项值最长 1000 字符，序列化后的总长度最长 4000 字节（UTF-8）。
- 批量导入和导出的多选列同样使用 JSON 数组，例如 `["研发","运维"]`。
- 读取填报数据时，多选列返回的是 JSON 数组字符串；需要逐项分析时按 JSON 解析。

## 常用命令入口

`hbi survey --help`：

- `list`：列出当前用户创建的模板，可过滤 `--title` / `--query`，支持 `--order-by` / `--order-type` / `--offset` / `--limit`。服务端默认只返回 10 条，JSON/YAML 输出保留 `totalHits`，table 输出会提示总数。
- `show <id>`：读取模板和完整控件定义
- `create --file survey.json`：创建模板；成功后 CLI 会回读完整模板（含 controls），回读失败会返回非零错误并提示模板已创建但未验证
- `update <id> --file survey.json`：更新模板；移除控件需要显式 `--allow-remove-controls`
- `delete <id> --force`：删除模板元数据（不删表）
- `setting get <id>`：读取填报状态、允许填报用户、匿名分享状态、平台数据标记
- `setting update <id> --file settings.json`：只允许修改 `status`（`OPEN` / `CLOSED`）
- `data <id>`：读取已提交的填报数据，支持 `--offset` / `--limit` / `--order-by` / `--order-type`

`--file` 也支持 `--value '<json>'` 直接传 JSON；两者都支持 JSON 或 YAML。

## 创建模板

先 `show` 或按现有模板结构准备完整 JSON：

```json
{
  "title": "客户回访",
  "formTitle": "请填写本次回访信息",
  "status": "OPEN",
  "connectionId": 12,
  "tablePath": ["public"],
  "table": "customer_visit",
  "options": {
    "submitButton": { "title": "提交" },
    "resetButton": { "enable": true, "title": "重置" },
    "canLookupData": false,
    "canUpdateData": false,
    "canImportData": false
  },
  "controls": [
    {
      "uuid": "01HX0000000000000000000001",
      "inputType": "singleLineText",
      "title": "客户名称",
      "fieldName": "customer_name",
      "required": true,
      "options": { "placeholder": "请输入客户名称" }
    },
    {
      "uuid": "01HX0000000000000000000002",
      "inputType": "checkboxInput",
      "title": "使用场景",
      "fieldName": "scenes",
      "required": true,
      "options": {
        "items": ["研发", "测试", "运维"],
        "styleType": "checkbox",
        "layout": "vertical"
      }
    }
  ]
}
```

```bash
hbi survey create --file survey.json --output json
hbi survey show <id> --output json
hbi survey data <id> --limit 20 --output json
```

## 更新模板

`update` 的 `controls` 是整表语义：

- 不传 `controls`：控件和落库列保持不变，只更新标题、输出配置等模板字段。
- 传 `controls` 数组：数组里缺失的控件会被当成删除，触发落库表删列，所以必须传完整列表。
- 传 `controls: []`：等价于删除全部控件列。
- CLI 会对比服务端当前控件，发现缺失 `uuid` 时默认拒绝；确实要删列时必须显式传 `--allow-remove-controls`。
- `show` 返回的 `id` / `createdBy` / `createdAt` / `updatedBy` / `updatedAt` 和 `options.version` 会在提交前自动剥离，不需要手工清理。

推荐流程：

1. `hbi survey show <id> --output json` 读取当前模板。
2. 只修改目标控件，保留其他控件和 `uuid`。
3. `hbi survey update <id> --file survey.json`。

不要只传一个控件；如果要改控件，就把完整 `controls` 列表一起传。

## 表单设置

`hbi survey setting get <id>` 读取设置页内容：

- `status`：填报开关（`OPEN` / `CLOSED`）；
- `allowUsers`：允许填报的用户 / 组织 / 部门 / 租户；
- `share`：匿名填报开关和分享 hash；
- `isPlatformData`：平台模板标记。

`hbi survey setting update <id> --value '{"status":"CLOSED"}'` 只允许改填报开关，且只接受 `OPEN` / `CLOSED`。

以下字段不走这个命令：

- `allowUsers` / `tenants` 等权限变更；
- `share.enable` / 分享 hash 重建。

它们属于权限或对外分享变更，必须走对应的权限/分享确认流程；CLI 会直接拒绝包含这些字段的 settings payload。

## 常见错误

- `options.items cannot be empty`：多选至少配置一个候选项。
- `options.items cannot have leading or trailing spaces` / `duplicates`：候选项需要先去空格、去重。
- 多选序列化后的值不能超过 4000 字节（UTF-8），单个选项不能超过 1000 字符；超出时服务端返回校验错误。
- `fieldName` 非法：只允许字母、数字、下划线，且不能使用 `hs_row_id`、`hs_user_id` 等系统列名。
- 表已存在：`table` 指向了同路径下已有的表，换表名或换路径。
- `status=OPEN` 但 `connectionId` / `tablePath` / `table` 不完整：先补全输出配置。
- 删除模板只删除模板记录，落库表和已提交数据保留；非交互环境必须显式 `--force`。

## Authoring session 边界

在 `data-agent-session-v1` authoring session 中，模板读取、创建、更新（含 `--allow-remove-controls` 的删列操作）和填报开关属于可恢复内容编辑；删除、权限变更、匿名分享、平台级模板管理、异步导入/导出属于高风险或未开放边界。当前服务端 delegated route catalog 放开 `GET/POST /api/surveys`、`GET/PUT /api/surveys/{id}`、`GET/PUT /api/surveys/{id}/setting`、`GET /api/surveys/{id}/data`，`DELETE` 仍被拒绝。以服务端 route admission 为准，`POLICY_DENIED` / `403` 时不要换相邻命令绕过。
