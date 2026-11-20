# Operation kinds and payloads

Source of truth at runtime: `hbi data-agent operation kinds --output json`.
If the server refuses that call (401/403), the current catalog is unreadable: report that you cannot confirm the operation is available and do not propose it. This file shows payload shapes only; it is not an allowlist.
Each catalog entry carries the admitted routes as `METHOD template (path: ...; query: ...)`.
The CLI turns the kind + payload below into the native `{method, path, query, body}`
request the server confirms and replays; do not handcraft that request JSON.

```bash
hbi data-agent operation propose --kind <kind> --value '<payload>' --output json
```

## 调度 / 执行

| User intent | Kind | Payload |
|---|---|---|
| 刷新数据集 / 立即运行一次 pipeline | `scheduler.create` | `{entityGroup, entityKey, execDetail, planItems:[{triggerType:"ONCE"}]}` |
| 每天定时刷新 | `scheduler.create` | 同上，`triggerType:"CRON_JOB"` + cron 字段 |
| 改执行时间 / 时区 | `scheduler.update` | `{scheduleId, cron?, timeZone?}` |
| 启停计划 | `scheduler.switch` | `{scheduleId, enabled}` |
| 删除计划 | `scheduler.delete` | `{scheduleId}` |
| 运行 notebook 段落 | `notebook.paragraph.run` | `{notebookId, paragraphId}` |

数据集刷新的完整示例见 `SKILL.md`；依赖与失败通知的修改暂未开放。

## 删除

| Kind | Payload |
|---|---|
| `dataset.field.delete` | `{appId, datasetId, fieldName}` |
| `dataset.delete` | `{appId, datasetId}` |
| `dashboard.delete` | `{appId, dashboardId}` |
| `pipeline.delete` | `{pipelineId}` |
| `app.delete` | `{appId}` |
| `notebook.delete` | `{notebookId}` |
| `notebook.paragraph.delete` | `{notebookId, paragraphId}` |
| `folder.delete` | `{folderId}` |
| `measure.delete` | `{appId, datasetId, measureName}` |
| `app.relation.delete` | `{appId, sourceId, type}`（`data_use` / `data_extend`） |
| `survey.delete` | `{surveyId}`（只删模板，已提交数据保留） |
| `common-dimension.delete` | `{appId, name}` |
| `granularity.delete` | `{appId, datasetId, granularityId}` |
| `connection.delete` | `{connectionId}` |
| `app.rule.delete` | `{appId, ruleId}` |
| `data-alert.delete` | `{appId, alertId}` |

## 授权 / 协作

Six legacy grant/revoke kinds have collapsed into one authorization kind per
target type. The endpoint does not expand deltas: it takes the complete
`AuthDto` in the body. The CLI reads the current list first, applies the
requested subjects locally, and submits the complete list. Other subjects keep
their existing roles.

```bash
hbi data-agent operation propose --kind app.authorize --value '{
  "targetId": 88,
  "grant":  [{"subjectType": "user", "subjectId": 1001, "role": "edit"}],
  "revoke": [{"subjectType": "group", "subjectId": 7}]
}' --output json
```

`subjectType` 四个取值不可混用：

- `user` — 用户（native `grantors`）
- `group` — **用户组**（后端 ident type 为 `org`，native `orgs`）
- `organization` — **组织架构**（native `organizations`）
- `tenant` — 租户（native `tenants`）

`role` 取 `view` / `edit` / `admin` / `tenant`。省略 `grant` 或 `revoke` 表示不改动该类。

| Kind | Target |
|---|---|
| `app.authorize` | `{targetId, grant?, revoke?, comment?}` |
| `folder.authorize` | 同上，`targetId` 是文件夹 ID |
| `connection.authorize` | 同上，`targetId` 是数据连接 ID |

## 权限规则

| Kind | Payload |
|---|---|
| `app.rule.create` | `{appId, name, type, options, dataFilters}`（`type` 取 `ROW` / `COLUMN`） |
| `app.rule.update` | create 的 payload + `ruleId` |

## 数据预警

| Kind | Payload |
|---|---|
| `data-alert.create` | `{appId, dashboardId, chartId, title, options}` |
| `data-alert.update` | `{alertId, title?, options?}`，只传要改的字段；另需 `appId` |
| `data-alert.delete` | `{appId, alertId}` |

## 明确不支持

- `connection.credential.replace`：提案 payload 不允许携带密码/密钥
- `app.dataset.replace`：需要文件上传/选择，暂不开放
