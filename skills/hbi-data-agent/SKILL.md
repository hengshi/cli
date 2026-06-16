---
name: hbi-data-agent
description: "Data Agent / ChatBI 领域技能。凡是用户提到 data-agent、copilot、ChatBI、AI 配置、ChatBI prompt、basePrompt、向量库初始化、HQLExample 向量状态，或需要围绕 `hbi data-agent` / `hbi copilot` 管理 AI 后台配置时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi data-agent --help"
---

# HBI Data Agent

> 前置：先读 `hbi-core`。本技能负责的是 Data Agent / ChatBI 的**后台治理面**，不是替用户直接发起聊天问答，也不是通用 `preferences` 配置入口。
>
> 需要写 `data-agent config update/verify` 的 `--file/--value` 载荷时，继续读 `references/config-payloads.md`。

## 资源边界

- `data-agent` 是独立顶层命令，另有 `copilot` alias。
- 当前稳定命令面只覆盖三类后台治理动作：
  - `config`：`/configurations/chat` 主配置的读取、校验、更新
  - `prompt`：`/prompts` 与 `/prompts/{name}` 的 prompt 模板管理
  - `vector`：`/configurations/chat/init-vector` 的系统级向量库初始化与状态查询
- 这不是“发起一次 ChatBI 问答”的命令面；不要臆造 `ask` / `chat` / `query` 子命令。
- 这也不是资源级向量化入口。资源级 AI / 向量化现在有第一批稳定 CLI 命令，但它们**不在** `data-agent` 子树下，而是分散在 `dataset` / `app` / `subject` / `scheduler`。

## 当前实现的关键限制

1. `config update` / `config verify` 接收的是 **JSON/YAML 对象载荷**。
   输入方式是二选一：
   - `--file <json-or-yaml>`
   - `--value '<json-or-yaml-string>'`
   `--dry-run` 时要能分清请求面：
   - `config verify --dry-run` → `POST /configurations/chat/verify`
   - `config update --dry-run` → `PUT /configurations/chat`

2. `config` / `prompt` / `vector` 在**不带子命令**时会回到当前最常用的读操作：
   - `data-agent config` → `get`
   - `data-agent prompt` → `list`
   - `data-agent vector` → `status`

3. `prompt update <NAME>` 只更新该 prompt 的 `basePrompt` 文本。
   它不是任意 JSON patch 接口，也不是改 model / metadata 的通用入口。
   `prompt get` / `prompt update` 的 prompt 名都是**位置参数 NAME**，不是 `--name` flag。
   `--dry-run` 时会显示 `PUT /prompts/<NAME>`，请求体也会被包成 `{"basePrompt":"..."}` 这种 JSON 对象，而不是直接把纯文本裸发出去。

4. `prompt update` 的内容输入也是二选一，但这里读的是**纯文本**：
   - `--file <text-file>`
   - `--value '<prompt text>'`

5. `vector status --type` 当前只显式支持一个稳定值：`hql-example`。
   这是 CLI 枚举值；不要把后端查询参数里的 `HQLExample` 大小写形式直接拿来当 CLI 输入，也不要编造 `dataset`、`subject`、`metric` 之类的 type。
   但如果你跑 `--dry-run`，最终请求行会显示 API 侧 query 值 `type=HQLExample`；CLI 输入和线上的 query 字符串不是同一层字面量。

6. 资源级 AI / 向量化现在已有第一批稳定 CLI 入口，但边界要分清：
   - `hbi dataset knowledge --app <app_id> --dataset <dataset_id> show|update`
   - `hbi dataset example --app <app_id> --dataset <dataset_id> create|show|update`
   - `hbi app vectorize-datasets <app_id>`
   - `hbi subject tokenize <subject_id>`
   - 进度观察统一回到 `hbi scheduler list --entity-group ...`
     - `ai-create-example`
     - `ai-rag-embedding`
     - `ai-rag-measure-subject-tokenize`
   这些都不是 `hbi data-agent` 子命令；如果用户问的是资源对象上的知识管理 / 学习 / tokenize，应该切到对应资源域，而不是继续留在本技能里发明 `data-agent dataset-*`。

7. `vector init` / `vector status` 都没有 `--file` / `--value` 这类载荷输入，`vector init` 也没有 `--type` 这种范围收缩参数。
   这里是固定的系统级治理动作，不是任意 payload authoring 面。

## 常用命令入口

`hbi data-agent --help`：

- `config`
- `prompt`
- `vector`

## 常见操作

### 主配置：先 `get`，再 `verify`，最后 `update`

```bash
hbi data-agent config get --output json
hbi data-agent config verify --file chat-config.yaml --dry-run
hbi data-agent config update --file chat-config.yaml --dry-run
hbi data-agent config update --value '{"enabled":true}' --dry-run
```

规则：

- `config get` 读的是当前 Data Agent / ChatBI 主配置，不要先跳到 `preferences get-config/set-config` 猜裸 key。
- `verify` 与 `update` 都要求对象载荷；不要传单个字符串、数字或 prompt 文本。
- 推荐顺序是：先 `get` 看现状，再 `verify` 校验，再 `update` 正式变更。
- `--dry-run` 会直接展示后端请求形态，适合先确认要发的是 `POST /configurations/chat/verify` 还是 `PUT /configurations/chat`。

### Prompt：先 `list/get` 定位，再 `update` basePrompt

```bash
hbi data-agent prompt list --output json
hbi data-agent prompt get UserSystem --output yaml
hbi data-agent prompt update DatasetSelector --file dataset-selector.txt --dry-run
hbi data-agent prompt update HQLExamples --value "Use only approved HQL examples."
```

规则：

- 位置参数 `NAME` 是 prompt 名称，例如 `UserSystem`、`HQLExamples`、`DatasetSelector`。
- `prompt update <NAME>` 更新的是该 prompt 的 `basePrompt` 文本，不要把它当成整个 prompt 对象的 JSON patch。
- `prompt get` / `prompt update` 都用位置参数 `NAME`，不要编造 `--name UserSystem`。
- `--file` / `--value` 在这里传的是**纯文本 prompt 内容**，不是 `{"basePrompt":"..."}` 这种 JSON 包装对象。
- 但 `prompt update --dry-run` 的请求预览里，CLI 仍会把正文包装成 `{"basePrompt":"..."}` 发往 `PUT /prompts/<NAME>`；不要把“输入是纯文本”误读成“线上请求体也是纯文本”。
- 如果用户要写 prompt 里的 HQL 示例内容，prompt 的更新动作留在本技能；HQL 语义本身再参考 `hql-expert`。

### 向量库：系统级 `init/status`，不是资源级 vectorization

```bash
hbi data-agent vector init --dry-run
hbi data-agent vector status --output json
hbi data-agent vector status --type hql-example --output json
```

规则：

- `vector init` 触发的是**系统级**向量库初始化，不是某个 app、dataset、subject 或 metric 的局部向量化。
- `vector status --type` 当前只支持 `hql-example`；如果你看到后端查询参数形态 `type=HQLExample`，那是 API 侧字符串，不是 CLI flag 值。
- `vector status --type hql-example --dry-run` 时，第一行会显示 `GET /configurations/chat/init-vector/status?type=HQLExample`；要同时记住 CLI 输入值和 API query 值。
- 如果用户只想看当前状态，`hbi data-agent vector` 不带子命令时默认就是 `status`。
- `vector init` / `vector status` 都不是 payload authoring 命令面；不要编造 `--file`、`--value`，也不要给 `vector init` 强加 `--type`。
- 如果问题已经变成“某个 dataset 的知识管理 / 学习结果怎么改”或“某个 app/subject 的向量化怎么触发”，就不要继续停在 `data-agent`，而要切到对应资源命令面。

## 推荐工作流

1. 先 `data-agent config get` 看当前 ChatBI 配置。
2. 用 `config verify --file/--value` 校验候选配置。
3. 再 `config update --file/--value` 正式更新。
4. 用 `prompt list` / `prompt get` 定位要改的 prompt。
5. 用 `prompt update <NAME> --file/--value` 更新 `basePrompt`。
6. 需要系统级向量库准备时，执行 `vector init`，再轮询 `vector status`。

## 何时转到别的技能

- 要处理认证、环境变量、全局输出、`preferences` / `config`：转 `hbi-core`
- 要改数据集知识管理 / 学习结果：转 `hbi-data`
- 要触发 app 级数据集向量化或看 scheduler AI 任务：转 `hbi-data` / `hbi-scheduler`
- 要触发主题域 tokenize：转 `hbi-indicator-center`
- 要改图表等被 ChatBI 消费的数据对象：转 `hbi-dashboard`
- 要写 prompt 里的复杂 HQL / HE 示例：转 `hql-expert`
- 要串联 dataset/app/subject/scheduler 的资源级 AI 链路：转 `hbi-workflow`

## 禁止事项

- 不要把 `data-agent` 说成 `preferences` 的一个分支。
- 不要臆造 `data-agent ask` / `chat` / `query` 这类不存在的子命令。
- 不要把 `prompt get` / `prompt update` 写成 `--name <prompt_name>`；当前是位置参数 `NAME`。
- 不要把 `prompt update` 说成能更新任意 prompt 字段；当前只稳定支持 `basePrompt` 文本。
- 不要把 `prompt update --value` 写成 JSON 对象；这里传的是原始文本。
- 不要把 `config update` / `verify` 的载荷写成标量；它们要求对象。
- 不要把 API 里的 `HQLExample` 大小写形式直接当成 CLI `--type` 值；CLI 这里写 `hql-example`。
- 不要编造 `vector status --type dataset`、`subject`、`metric` 等不存在的 type。
- 不要把 `dataset knowledge/example`、`app vectorize-datasets`、`subject tokenize` 重新包装成 `hbi data-agent` 子命令。
