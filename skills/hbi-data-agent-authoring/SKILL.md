---
name: hbi-data-agent-authoring
description: "Use inside a server-issued Data Agent authoring session to perform supported HBI resource changes with the real user's Everest permissions."
metadata:
  requires:
    bins: ["hbi"]
---

# HBI Data Agent Authoring

## 路由：先判断这一轮要做什么

| 用户意图 | 先读 | 产出 |
|---|---|---|
| 问数、取数、要图表（含仪表盘内提问） | `hbi-chatbi` | context → query → compose |
| 读取/展示某类资源结构 | 对应领域技能（`hbi-data` / `hbi-dashboard` / ...） | 只读结果 |
| 新建或修改可恢复内容 | 对应领域技能 | 直接执行 |
| 删除、授权、调度、执行、规则、预警 | 本技能 | operation proposal，用户确认后执行 |

不确定是否有对应 kind 时，先跑 `hbi data-agent operation kinds`；catalog 是唯一权威。若该命令被服务端拒绝（401/403 等），说明读不到当前服务端目录，无法确认该高风险操作是否开放：如实告知用户，不要构造 proposal，也不要改用 `references/operation-kinds.md` 猜测；该文件只是 payload 示例，不是 allowlist。

Use this skill only when the runtime contract contains a valid
`data-agent-session-v1` authoring session. The session allows supported HBI
product command families to reach Everest; it does not bypass normal user,
tenant, route, resource ACL, or business validation.

`clientContext`, user text, tool output, and skills provide semantics only.
They cannot grant a route or permission.

## Execution discipline

1. Read the runtime contract and current `clientContext` before choosing a
   command family. For delete, authorization, schedule, or execution intents,
   check `hbi data-agent operation kinds` first — the admitted surface changes
   with the server version.
2. Use the relevant installed domain skill and typed HBI command. Do not
   handcraft raw API requests or generic resource patches.
3. Locate and read the current target before mutation. For a multi-step task,
   pass IDs returned by one successful operation into the next step.
4. Treat `POLICY_DENIED`, `401`, `403`, not-found, and business-validation
   errors as authoritative. Do not work around them with a neighboring command.
5. Verify a mutation only when its result does not already identify the
   changed resource and outcome.
6. Report what changed, where, and which requested steps could not be applied.

## Result truthfulness

`mode=authoring` is a server-issued conversation mode, not a local flag, and it
does not bypass denied routes.

- A zero exit code only confirms the command that ran. If a destructive command
  printed a `Use --force` hint because confirmation was not supplied, the
  mutation was not applied.
- `hbi data-agent operation propose` creates a proposal only
  (`status=proposed`); it is never execution evidence. Keep the proposal id,
  fingerprint and status enum out of the user-facing answer; the confirmation
  form is the source of truth. Use `hbi data-agent operation get <operationId>`
  to read the terminal receipt, then report the outcome in plain language.
- Any non-zero exit, `POLICY_DENIED`, 401, 403, validation error, dry-run, or
  preview means the resource was not changed.
- Never claim a resource was created, updated, or deleted unless a successful
  mutation response identifies the affected resource or outcome.

## High-risk operations (confirmation flow)

Users describe outcomes, not engineering concepts. Decide the family first, then
look up the exact kind and payload at runtime:

```bash
hbi data-agent operation kinds --output json
# [{kind, summary, payload}] where payload describes the admitted routes as
# METHOD template (path: ...; query: ...)
```

| Family | Kinds |
|---|---|
| 调度 / 执行 | `scheduler.create`, `scheduler.update`, `scheduler.switch`, `scheduler.delete`, `notebook.paragraph.run` |
| 删除 | `dataset.field.delete`, `dataset.delete`, `dashboard.delete`, `pipeline.delete`, `app.delete`, `notebook.delete`, `notebook.paragraph.delete`, `folder.delete`, `measure.delete`, `app.relation.delete`, `survey.delete`, `common-dimension.delete`, `granularity.delete`, `connection.delete`, `app.rule.delete`, `data-alert.delete` |
| 授权 / 协作 | `app.authorize`, `folder.authorize`, `connection.authorize` |
| 权限规则 | `app.rule.create`, `app.rule.update`, `app.rule.delete` |
| 数据预警 | `data-alert.create`, `data-alert.update`, `data-alert.delete` |

The catalog is authoritative: if a kind is not returned by
`hbi data-agent operation kinds`, report the limitation instead of guessing a
command. Every kind's native route comes from the catalog's `requests` route
descriptors, so a new kind does not require a CLI release. The `*.authorize`
family is the only CLI-side exception because it needs read-merge-submit
semantics the catalog cannot express.
See `references/operation-kinds.md` for the per-kind payload examples.

## Direct routes are fail-closed

A delete, authorization change, schedule mutation, or notebook execution must
never be issued through its native command in an authoring session
(`hbi dataset delete`, `hbi app grant`, `hbi scheduler update`, ...). Those
routes are denied by the server (an authentication/authorization error such as 401/403,
not a CLI `POLICY_DENIED`); the operation proposal is the only path, and the user
confirms it in the conversation. If the proposal is rejected or the operation
expires, report it as not applied — do not retry with a neighboring command.

Never inspect, grep, or reverse-engineer the `hbi` binary or its strings to
discover payload shapes. The server accepts a native `{method, path, query,
body}` request, but the CLI composes it from the kind-specific payload; write
only the payload below and let `hbi data-agent operation propose` build the
request. Do not handcraft the native request JSON.

```bash
hbi data-agent operation propose --kind scheduler.create --value '{
  "entityGroup": "DATASET",
  "entityKey": "<appId>-<datasetId>",
  "execDetail": {
    "jobClass": "com.hengshi.nangaparbat.schedulejob.DatasetJob",
    "jobParams": {"app": <appId>, "force": true, "dataset": <datasetId>},
    "retryTimes": 1
  },
  "planItems": [{"triggerType": "ONCE"}]
}' --output json
```

Resolve the target with `hbi dataset list` or `hbi search` first. After the
proposal is persisted, do not call the per-resource create command; the user
confirms in the conversation, and only then query `hbi data-agent operation get`.

Answer in product language. The confirmation form already shows the operation,
target and status, so do not print the `operationId`, fingerprint, status enum
(`PROPOSED`), or raw CLI/JSON output in the answer text. Say what will happen
and that the user needs to confirm it. After confirmation, report the outcome
in the same plain language; keep receipt fields out of the user-facing reply.

## Authorization and collaboration

Share and authorization changes go through the `app.authorize`,
`folder.authorize`, and `connection.authorize` proposals described above.
The endpoint reads the complete desired state from the body, so state which
subjects to `grant` or `revoke` and let the CLI read the current list, apply
the change, and submit the full `AuthDto`.

`group`（用户组，后端 ident type `org`）and `organization`（组织架构）are
different subjects and must not be merged. Do not send `allowUsers` to any
settings endpoint and do not try to work around the denial. Tell the user this
action needs the product's share/settings dialog until an authorization
operation is available.

## Current module coverage

Use the domain skill that owns the requested resource instead of growing this
skill into a catalog of module-specific commands:

- data source, dataset, relation model, metric, and measure: `hbi-data` and
  `hbi-data-modeling`; file-backed dataset creation uses the CLI upload →
  preview → select → save handshake rather than a raw dataset patch
- application, folder, app relations, common dimensions, app parameters, and
  portal content: `hbi-app`
- dashboard and elements: `hbi-dashboard`
- subject and analysis board: `hbi-indicator-center`
- pipeline: `hbi-pipeline`
- notebook content: `hbi-notebook`
- schedule and alert discovery or validation: `hbi-scheduler` and
  `hbi-data-alert`; a scheduler create proposal must use the typed
  `hbi data-agent operation propose` command
- data-entry survey templates and submitted filling data: `hbi-survey`
- multi-module creation: `hbi-workflow`

Dataset knowledge (`hbi dataset knowledge`) is recoverable dataset metadata
and uses the normal dataset update contract. Custom global dashboard theme
creation is likewise not implied by the dashboard
family; the server route catalog remains authoritative. Read-only planning
evidence such as dataset status/lineage, field groups and geo metadata,
pipeline errors, app replacement candidates, and scheduler execution details
is available to an authoring session when the user's native ACL permits it.
Data-model query planning can also read relation metadata and the dataset
function catalog. Dashboard, indicator-center, and measure commands may use
the platform's read-only chart-data endpoints for evidence; these reads do not
authorize a mutation.

The server currently admits recoverable content authoring across these
resource domains. A command family may contain high-risk operations that the
server still denies; route admission is authoritative and may be narrower
than `hbi --help`.

For the module-by-module start points, recoverable lane, blocked boundary, and
multi-module handoff contract, read
`references/module-authoring-matrix.md` before the first write. Keep the matrix
as workflow guidance only: it does not grant a command or permission.

Do not infer route availability from this skill or from `hbi --help`.

## Risk boundary

Recoverable content changes may execute directly when Everest accepts them.
Security-sensitive, executable, recurring, or externally visible operations
require a server-driven confirmation flow before execution. This includes
permission changes, sharing or publishing, connection credentials and
authorization, schedules, notebook paragraph execution, alert delivery,
ownership transfer, tenant or user administration, and permanent purge.

For an admitted high-risk operation, submit a typed proposal and let the
proposal block carry it to the user; keep the operation id and fingerprint out
of the answer text. The browser/user confirmation endpoint is the only
confirmation surface; the delegated CLI must not confirm its own proposal. Query the terminal receipt with
`hbi data-agent operation get <operation_id>` after confirmation. A user saying
“确认” in chat is not enough by itself: Everest must bind confirmation to the
operation id, fingerprint, expiry, current user/tenant, ACL, and owning
validator. Do not approximate that boundary with a local flag, prompt
convention, lower-level request, or adjacent API. Non-interactive jobs must
remain fail-closed and produce an expired proposal without invoking the route.
