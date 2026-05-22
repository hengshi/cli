---
name: hbi-data-alert
description: "数据预警领域技能。凡是用户提到 data-alert、数据预警、图表阈值告警、chart alert、指标阈值通知、webhook/email 告警、预警校验、预警启停，或需要围绕 `hbi data-alert` 给应用内图表配置阈值预警时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi data-alert --help"
---

# HBI Data Alert

> 前置：先读 `hbi-core`。需要定位 app / dashboard / chart 或图表 metric uid 时，可同时参考 `hbi-dashboard` / `hbi-data`。如果问题已经变成 schedule context / logs 排障，再切 `hbi-scheduler`。

## 资源边界

- `data-alert` 是**应用内图表预警资源**，绑定 `app + dashboard + chart`，不是 dashboard 布局配置，也不是通用 `scheduler` 创建入口。
- `create` 与 `validate` 的参数骨架一致：都要求 `APP_ID`、`DASHBOARD_ID`、`CHART_ID`、`TITLE`、`--metric-uid`。
- 预警条件比较的是 **chart metric uid**，不是 dataset 字段名、不是自然语言指标名、也不是随手写的 HQL。
- 当前 `update` 很窄：只支持 `--title`、`--enable`、`--disable`。如果要改 `metric_uid`、`operator`、`value/param`、`cron`、webhook 或 email 内容，不要指望 `update` 全量改配置；先 `validate` 新配置，再重建 alert。
- `show` / `list` / `enable` / `disable` 管的是 alert 资源；如果任务已经变成调度上下文与日志排障，再转 `scheduler`。

## 常用命令入口

`hbi data-alert --help`：

- `list`
- `show`
- `create`
- `update`
- `delete`
- `enable`
- `disable`
- `validate`

## 常见操作

### 先 `validate`，再 `create`

```bash
hbi data-alert validate <app_id> <dashboard_id> <chart_id> "GMV too low" \
  --metric-uid u_gmv \
  --value 100 \
  --webhook-url https://example.com/hook

hbi data-alert create <app_id> <dashboard_id> <chart_id> "GMV too low" \
  --metric-uid u_gmv \
  --value 100 \
  --webhook-url https://example.com/hook
```

规则：

- `validate` 与 `create` 共享同一套请求结构；先 `validate` 更适合暴露资源不存在、条件不合法、通知配置缺失等问题。
- `create` / `validate --dry-run` 当前直接打印**要提交的请求 JSON**，不是 method/path 预览，也不是 scheduler plan 预览。
- 最小 webhook 路径的 dry-run 默认值是稳定的：
  - `options.timing.cronType = WEEKLY`
  - `options.timing.cronDesc = 0 0 0 ? * 1`
  - `options.timing.triggerType = CRON_JOB`
  - `options.timing.frequency = ALWAYS`
  - `options.webhook.requestBody = "{}"`
  - `errorPolice.interval = 5`
  - `errorPolice.retryable = false`
- 如果还不知道 `metric_uid`，先回图表运行时去确认，不要拿字段名硬猜。
- `list` 支持按 `--dashboard`、`--chart`、`--title`、`--status`、`--enabled`、`--disabled`、`--query`、分页参数过滤。
- `list` 的应用 ID 是位置参数 `APP_ID`，不是 `--app`；`--dashboard` / `--chart` 也是稳定旗标，不是 `--dashboard-id` / `--chart-id`。
- `--enabled` / `--disabled` 是二选一的布尔旗标，不要写成 `--enabled false` 这种形态。

### 告警条件：`--value` / `--param` / `--operator` 的边界

```bash
hbi data-alert validate <app_id> <dashboard_id> <chart_id> "GMV below param" \
  --metric-uid u_gmv \
  --operator "<" \
  --param threshold_param \
  --webhook-url https://example.com/hook
```

规则：

- `--value` 和 `--param` **互斥**，不能一起给。
- `isnull` / `isnotnull` 是**一元操作符**，不能再配 `--value` 或 `--param`。
- 除了这类一元操作符，其他比较操作都需要在 `--value` / `--param` 里二选一。
- `--value` 会优先按 JSON literal 解析：`100`、`true`、`null` 会保留类型，不会一律当字符串。
- `--metric-uid` 不能为空；它指向的是图表 metric uid，不是 dataset 字段。

### 通知方式：webhook / email 至少要有一种

```bash
hbi data-alert create <app_id> <dashboard_id> <chart_id> "GMV webhook" \
  --metric-uid u_gmv \
  --value 100 \
  --webhook-url https://example.com/hook \
  --webhook-method POST \
  --webhook-header Authorization=Bearer-token

hbi data-alert create <app_id> <dashboard_id> <chart_id> "GMV email" \
  --metric-uid u_gmv \
  --value 100 \
  --email \
  --email-address ops@example.com \
  --email-subject "GMV warning" \
  --email-body "Please inspect the chart."
```

规则：

- 至少要有一种通知方式：`--webhook-url` 或完整的 email 配置；不能先创建一个“空通知”的 alert。
- `--webhook-method` / `--webhook-body` / `--webhook-header` 都依赖 `--webhook-url`。
- `POST` / `PUT` 的 webhook body 默认是 `{}`；如果你显式传 `--webhook-body`，CLI 只会对 `POST` / `PUT` 强制校验合法 JSON。
- `GET` / `DELETE` 没有同样的 JSON 解析要求；显式 `--webhook-body` 会按原样透传。
- `--webhook-header` 的格式固定是 `Name=Value`。
- Email 不只是 `--email` 一个开关：至少还要给一个 `--email-address`，并同时提供 `--email-subject` 与 `--email-body`。

### 定时与默认值

```bash
hbi data-alert create <app_id> <dashboard_id> <chart_id> "Weekly GMV check" \
  --metric-uid u_gmv \
  --value 100 \
  --cron "0 9 * * 1" \
  --frequency ONLY_ONCE \
  --webhook-url https://example.com/hook
```

规则：

- `--cron` 支持 5 段或 6 段；5 段会自动补秒位，归一成 6 段。
- 如果传了 `--cron` 但没传 `--cron-type`，CLI 会落成 `CRON`。
- 如果 `--cron` 和 `--cron-type` 都不传，默认 timing 是 `WEEKLY` + `0 0 0 ? * 1`。
- 默认 `--frequency` 是 `ALWAYS`。

### 创建后治理与排障

```bash
hbi data-alert show <app_id> <alert_id> --output json
hbi data-alert update <app_id> <alert_id> --title "new title"
hbi data-alert disable <app_id> <alert_id>

hbi scheduler list --entity-group data-alert --entity-key <entity_key_from_alert_show> --output json
hbi scheduler context <context_id> --output json
hbi scheduler logs <context_id>
```

规则：

- `show` 会返回 alert 的 `status`、`enabled`、`jobStatus`、`nextStartAt`，有时还会带 `entityKey`。
- 默认 table 模式的 `show` 不会把 `entityKey` 单独打印出来；如果要拿去给 `scheduler list --entity-key`，优先 `show --output json`。
- 如果要转去 `scheduler` 看 context / logs，优先复用 `show` 里的 `entityKey`；不要直接假设等于 `alert_id`。
- `update` 只适合改标题或启停，不适合改阈值逻辑、cron 或通知载荷。
- `update` 当前只接受 `--title`、`--enable`、`--disable`；如果三者都不传，CLI 会直接报错。

## 推荐工作流

1. 先确认 `app_id`、`dashboard_id`、`chart_id`，并准备好 `metric_uid`。
2. 用 `data-alert validate` 先验证条件与通知配置。
3. 再用 `data-alert create` 正式创建。
4. 用 `show` / `list` 确认落盘状态与启停结果。
5. 标题或启停改动走 `update` / `enable` / `disable`；执行排障再转 `hbi-scheduler`。

## 何时转到别的技能

- 要创建 dashboard / chart / filter / page：转 `hbi-dashboard`
- 要准备 dataset、字段、原子指标：转 `hbi-data`
- 要写复杂公式而不是引用现成 metric uid：转 `hql-expert`
- 要看 schedule context / logs / 依赖 / 通用调度治理：转 `hbi-scheduler`

## 禁止事项

- 不要把 dataset 字段名当成 `--metric-uid`。
- 不要同时传 `--value` 和 `--param`。
- 不要给 `isnull` / `isnotnull` 再配 `--value` 或 `--param`。
- 不要以为 `data-alert update` 能改 metric、cron、webhook 或 email 正文。
- 不要在没有 webhook 或 email 的情况下创建 alert。
- 不要在没有 `--webhook-url` 时先传 webhook body / header。
- 不要把 `scheduler` 的 `entity-key` 直接等同于 `alert_id`。
