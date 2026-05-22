---
name: hbi-scheduler
description: "调度治理领域技能。凡是用户提到 scheduler、cron、计划任务、schedule id、context/logs、已有计划的启停/改 cron/依赖/失败通知/时区，或需要围绕 `hbi scheduler` 管理 pipeline/notebook/dataset/data-alert/app-refresh/app-email 的已存在计划时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi scheduler --help"
---

# HBI Scheduler

> 前置：先读 `hbi-core`。如果用户还在创建资源本体或首次创建计划，先回对应领域技能；这里负责的是**已有计划的治理面**。

## 资源边界

- `scheduler` 管的是已经存在的执行计划与执行上下文，不负责替资源做“首次创建计划”。
- 首次创建入口仍在各自资源面：
  - `pipeline schedule <pipeline_id> create`
  - `notebook schedule <notebook_id> create`
  - `dataset schedule --app <app_id> --dataset <dataset_id> create`
  - `app refresh-schedule <app_id> create`
  - `data-alert create` / `validate`（预警配置里直接内嵌 timing 与通知）
- `show` / `update` / `delete` / `switch` 用的是 **schedule_id**。
- `context` / `logs` 用的是 **context_id**，不是 `schedule_id`。
- `list` 必须先给 `--entity-group`，再按需加 `--entity-key` / `--query` / `--enabled`。

## `entity-group` 与 `entity-key`

| entity-group | 适用资源 | 常用 entity-key |
|---|---|---|
| `pipeline` | 数据集成 pipeline 计划 | `<pipeline_id>` |
| `notebook` | 数据科学 notebook 计划 | `<notebook_id>` |
| `dataset` | 数据集刷新计划 | `<app_id>-<dataset_id>` |
| `data-alert` | 数据预警关联的调度实体 | 优先从 `data-alert show` 返回的 `entityKey` 读取，不要假设等于 `alert_id` |
| `app-refresh` | 应用刷新计划 | `<app_id>` |
| `app-email` | 应用邮件类计划 | 先 `scheduler list --entity-group app-email --query ...` 或从上游资源详情拿 `entityKey`，不要臆造 |

## 常用命令入口

`hbi scheduler --help`：

- `list`
- `show`
- `update`
- `delete`
- `switch`
- `context`
- `logs`

## 常见操作

### 先定位计划，再读详情

```bash
hbi scheduler list --entity-group notebook --entity-key <notebook_id> --output json
hbi scheduler list --entity-group dataset --entity-key <app_id>-<dataset_id> --output json
hbi scheduler list --entity-group app-refresh --entity-key <app_id> --output json
hbi data-alert show <app_id> <alert_id> --output json
hbi scheduler list --entity-group data-alert --entity-key <entity_key_from_alert_show> --output json
hbi scheduler show <schedule_id> --output json
```

规则：

- 如果只知道资源 ID，先 `list`；如果已经有 `schedule_id`，再 `show`。
- 对 `data-alert`，优先先 `data-alert show` 看 `entityKey`；不要直接把 `alert_id` 当成 `entity-key`。
- `show` 是 update 前最稳的预检入口，因为它会暴露 `planItems`、`priority`、`upStreamPlanIds`、`options`、`contextId`。

### 改 cron、依赖、失败通知：统一走 `scheduler update`

```bash
hbi scheduler update <schedule_id> \
  --cron "15 9 ? * 2" \
  --priority high \
  --retry-times 2 \
  --expired-time 45 \
  --depends-on 11 \
  --depends-on 12 \
  --notify-users-on-failure \
  --notify-user 1001 \
  --notify-user 1002 \
  --time-zone UTC \
  --output json
```

规则：

- `update` 不是盲目的“只 patch 你传的那个字段”。CLI 会先读取当前 schedule，再保留 `entityGroup` / `entityKey` / `jobClass` / `jobParams` 等稳定字段，只覆盖你显式改动的部分。
- 传了 `--cron` 就是**整体替换**当前 `planItems`，不是追加一条。
- 传了 `--depends-on` 就是**整体替换**依赖列表；`--clear-depends-on` 才是清空。
- 传了 `--notify-user` 就是**整体替换**失败通知用户列表；`--clear-notify-users` 才是清空。
- `--notify-users-on-failure` 在 schedule 处于 enabled 状态时，必须至少配一个 `--notify-user`。
- 不能同时给 `--enable` 和 `--disable`；也不能同时给 `--ignore-parent-trigger` 和 `--respect-parent-trigger`。
- Cron 支持 5 段或 6 段；CLI 会归一成 6 段。默认时区是 `Asia/Shanghai`。

### 纯启停优先用 `switch`，执行排障看 `context` / `logs`

```bash
hbi scheduler switch <schedule_id> --action disable
hbi scheduler context <context_id> --output json
hbi scheduler logs <context_id>
```

规则：

- 如果只是简单启用/停用，优先 `switch`；如果还要改 cron、通知、依赖，再用 `update`。
- `context` 看的是执行状态、开始/结束时间、耗时。
- `logs` 看的是上下文日志分组。
- 如果 `scheduler show` 里拿到了 `contextId`，后续喂给 `context` / `logs` 的就是这个值，不是 `schedule_id`。

### `app-refresh` 与 `data-alert` 的切换边界

```bash
hbi app refresh-schedule <app_id> create --cron "0 0 2 * * *"
hbi scheduler list --entity-group app-refresh --entity-key <app_id> --output json

hbi data-alert create <app_id> <dashboard_id> <chart_id> "GMV too low" \
  --metric-uid u_gmv \
  --value 100 \
  --webhook-url https://example.com/hook
hbi data-alert show <app_id> <alert_id> --output json
hbi scheduler list --entity-group data-alert --entity-key <entity_key_from_alert_show> --output json
```

规则：

- `app refresh-schedule` 的**首次创建**入口仍在 `hbi-app`，不是 `scheduler`。
- `data-alert` 的阈值、通知内容、启停与资源生命周期仍在 `hbi-data-alert`。
- 一旦问题变成“已经有计划了，我要查 schedule、改依赖、看 context/logs”，再回到本技能。

## 推荐工作流

1. 先判断当前问题是不是“首次创建计划”；如果是，回上游领域技能。
2. 用 `scheduler list --entity-group ... --entity-key ...` 找到目标计划。
3. 用 `scheduler show <schedule_id> --output json` 看当前 `planItems` / `options` / `contextId`。
4. 简单启停用 `switch`；复杂变更用 `update`。
5. 真实执行异常再看 `context` / `logs`。

## 何时转到别的技能

- 要创建 pipeline / notebook / dataset 的首次计划：转 `hbi-pipeline`、`hbi-notebook`、`hbi-data`
- 要创建应用刷新计划：转 `hbi-app`
- 要创建或重写数据预警阈值 / 通知配置：转 `hbi-data-alert`
- 要处理资源本体而不是 schedule 治理：回对应资源技能

## 禁止事项

- 不要把 `scheduler` 当成资源级首次创建入口。
- 不要把 `schedule_id` 和 `context_id` 混用。
- 不要把 dataset 的 `entity-key` 写成单独的 `<dataset_id>`；它是 `<app_id>-<dataset_id>`。
- 不要假设 `data-alert` 的 `entity-key` 一定等于 `alert_id`。
- 不要把 `--depends-on`、`--notify-user` 理解成追加语义；它们在 update 里是替换语义。
- 不要忘记 `scheduler list` 的 `--entity-group` 是必填。
