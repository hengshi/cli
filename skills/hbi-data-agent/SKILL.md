---
name: hbi-data-agent
description: "Data Agent 后台配置治理命令（不是问数，也不是变更执行）。用于主配置、Responses API 模型 Profile 与 runtime skill 管理。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi data-agent --help"
---

# HBI Data Agent

> 前置：先读 `hbi-core`。本技能负责 Data Agent / ChatBI 的后台治理，不负责直接发起聊天问答，也不是通用 `preferences` 配置入口。
>
> 旧的 `data-agent prompt` 和系统级 `data-agent vector` 命令已退役，不要再使用或推荐它们。

## 资源边界

- `data-agent` 是独立顶层命令，另有 `copilot` alias。
- 当前公开命令面覆盖四类操作：
  - `config`：`/configurations/chat` 主配置的读取和更新
  - `profile`：`/configurations/chat/model-profiles` Responses API 模型配置管理
  - `skills`：`/configurations/chat/runtime-skills` runtime skill 上传、启停和删除
  - `operation`：server-owned authoring operation proposal/receipt 的 typed 读取与提案
- `runtime-skills sync` 是隐藏的 Agent job provisioning 命令，不是普通用户的管理入口。
- 资源级数据知识、字段值索引和主题域 context/query 仍属于对应资源命令，不要包装成 `data-agent` 子命令。

## 常用命令入口

```bash
hbi data-agent config --help
hbi data-agent profile --help
hbi data-agent skills --help
hbi data-agent operation --help
```

## 主配置

`config` 接收 JSON/YAML 对象载荷，直接对应 `/configurations/chat`；它不再承载模型地址、模型名、API key 或推理参数。

```bash
hbi data-agent config get --output json
hbi data-agent config update --file chat-config.yaml --dry-run
hbi data-agent config update --file chat-config.yaml
```

最稳的 workflow 是 `get -> 编辑 -> update --dry-run -> update`。不要给 payload 额外包 `config:` wrapper，也不要传标量、数组或 prompt 文本。

## Responses API 模型 Profile

Profile 是当前认证范围内的模型配置。创建和编辑只做本地校验与持久化；模型连通性测试使用 `verify`，不会创建 sandbox。

```bash
hbi data-agent profile list --output json
hbi data-agent profile create --file profile.json --dry-run
hbi data-agent profile update <profile-id> --file profile.json --dry-run
hbi data-agent profile headers set <profile-id> --name X-Caller --value "$CALLER_TOKEN"
hbi data-agent profile headers remove <profile-id> --name X-Caller
hbi data-agent profile headers clear <profile-id>
hbi data-agent profile verify --file profile.json
hbi data-agent profile activate <profile-id>
hbi data-agent profile deactivate <profile-id>
hbi data-agent profile delete <profile-id>
```

`profile.json` 是一个对象，字段按当前后端契约填写，例如 `name`、`responsesBaseUrl`、`model`、`apiKey`、`authHeader`、`authHeaderValuePrefix`、`reasoningEffort` 和 `timeoutSeconds`。编辑已保存 Profile 时，服务端返回的 `apiKey: "******"` 可以原样回传以保留原 secret。

`profile headers` 是对已保存 Profile 的增量操作。CLI 会先读取目标 Profile，再保留其他字段和密钥，只更新 `extraHeaders`；适合为沙箱内的 Responses 代理补充固定认证头。`set` 会按名称（不区分大小写）替换已有值，`remove` 和 `clear` 不会打印被删除的 secret。固定值建议通过环境变量传给 `--value`，不要直接写入 shell history。

## Runtime skills

Runtime skill 是平台管理员上传的不可变、版本化 ZIP。每个归档必须包含 `<id>/SKILL.md`；内容变化应使用新版本号。启停和切换只影响之后创建的 job，不能修改已经创建的 job 快照。

```bash
hbi data-agent skills list --output json
hbi data-agent skills upload \
  --id retail-analysis --version 1.0.0 --file retail-analysis.zip
hbi data-agent skills activate retail-analysis 1.0.0
hbi data-agent skills deactivate retail-analysis
hbi data-agent skills delete retail-analysis 1.0.0
```

`skills upload` 使用 multipart 请求；`--file` 指向 ZIP，而不是 `SKILL.md` 裸文本。平台 API 会校验归档路径、大小、条目数和不可变版本约束。

## Operation

Operation 只负责提交和读取需要用户确认的外部效果提案。服务端只接受 native request：
CLI 会把下面这些 kind 对应的资源 payload 组合成 `{method, path, query, body}`，
调用方不需要（也不应该）自己写 request JSON。

| kind | payload |
|---|---|
| `scheduler.create` | `entityGroup` / `entityKey` / `execDetail` / `planItems` |
| `dataset.field.delete` | `{appId, datasetId, fieldName}` |
| `app.authorize` / `folder.authorize` / `connection.authorize` | `{targetId, grant:[{subjectType,subjectId,role}], revoke:[{subjectType,subjectId}]}`；CLI 先读取当前授权列表，再提交完整 AuthDto |

支持的路由以服务端目录为准，用 `hbi data-agent operation kinds --output json` 查询；
目录返回每个 kind 的 `summary` 和 `payload`（内容为 `METHOD template (path: ...; query: ...)`），
不要在客户端枚举里假设某个 kind 一定存在。

授权/回收已合并为每个 target type 一个 kind，服务端不做 delta 展开：CLI 会读取当前
授权列表，在本地应用 `grant` / `revoke` 后把完整列表提交到 `POST /api/authorize`。

确认不在 CLI 内完成；提案只创建 `proposed` 状态，用户必须在对话里的确认表单中确认。

```bash
hbi data-agent operation propose --kind scheduler.create \
  --file plan.json --interaction-mode interactive --output json
hbi data-agent operation propose --kind dataset.field.delete \
  --value '{"appId":1,"datasetId":2,"fieldName":"c0"}' --output json
hbi data-agent operation get <operation_id> --output json
```

## 何时转到别的技能

- 认证、环境变量、全局输出：转 `hbi-core`
- 数据集知识 / 学习结果：转 `hbi-data`
- 应用级字段值搜索索引和 AI scheduler：转 `hbi-data` / `hbi-scheduler`
- 主题域 context/query：转 `hbi-indicator-center`
- 仪表盘或图表：转 `hbi-dashboard`
- 跨多个资源域编排：转 `hbi-workflow`

## 禁止事项

- 不要恢复或推荐 `hbi data-agent prompt ...`。
- 不要恢复或推荐 `hbi data-agent vector init/status`。
- 不要把 `data-agent` 说成 `preferences` 的子命令。
- 不要臆造 `data-agent ask`、`chat` 或 `query`。
- 不要把 runtime skill 管理和隐藏的 `runtime-skills sync` 混为一谈。
