---
name: hbi-indicator-center
description: "业务指标中心领域技能。凡是用户提到业务指标中心、主题域、主题域指标、分析看板、指标上墙、subject、kanban，或需要围绕 `hbi subject` / `hbi kanban` 走 measure-centric 工作流时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi subject --help && hbi kanban --help"
---

# HBI Indicator Center

> 前置：先读 `hbi-core`。本技能负责的是 **subject + kanban** 这条业务指标中心链路；`measure` 本身的创建/公式语义仍属于 `hbi-data` / `hql-expert`。
>
> 需要写 `kanban export` 的 `--file/--value` 载荷时，继续读 `references/kanban-export.md`。

## 资源边界

- `subject` 是**主题域**：它本质上是 `area=SUBJECT_AREA` 的目录树，用来组织业务指标（measure）。
- `kanban` 是**分析看板**：它不是普通 `dashboard`，而是围绕主题域指标组织的 measure-centric 看板。
- 这条链通常是：
  1. 先在 `hbi-data` 里 `measure create/list/show`
  2. 再用本技能把 measure 挂到 `subject`
  3. 再用 `kanban` 把主题域指标上墙
- 如果用户要的是普通 dashboard 页面、图表布局、dashboard plan YAML，不要留在本技能，转 `hbi-dashboard`；6.2 起普通 dashboard chart 也可以通过 `measureSubjectId` 使用主题域指标作图。
- 如果用户要共享/授权主题域看板，再转 `hbi-permission`。

## 当前实现的关键合同

1. `subject add-metrics` / `remove-metrics` / `toggle-online` 的 `<METRICS>` 都是**位置参数字符串**，格式必须是：
   - `appId:datasetId:fieldName`
   - 支持逗号分隔多个，例如 `3034:4:m1,3034:4:m2`
   - 这里**不是** metric id，也不是 `subject list-metrics` 返回的 `id`

2. `subject list-metrics <subject_id>` 才是“列出当前主题域里挂了哪些指标”的入口。
   - 它返回的 `id` 可以给 `kanban add-metric --metric`
   - 它返回的 `id` 也可以给普通 dashboard chart 的 `element chart create --measure-subject <subject_id> --subject-measure <id>`
   - 因此 `subject` 与 `kanban` 用的“指标标识”不是同一套
   - 它是列表型 tool result，默认只返回 agent-safe 第一页；数量类问题读取输出 envelope 的 `total`，不要用 `--all` 拉全量再让模型数。

3. `subject toggle-online` 必须显式给且只给一个状态：
   - `--online`
   - `--offline`
   不带 flag 不会默认 offline，同时给两个也不行。

4. `subject create <title>` 可以不带 `--parent`。
    - CLI 会先取主题域 root，再把新主题域挂到 root 下
    - 创建时父主题域参数是 `--parent`，不是 `--folder`
    - 如果要建嵌套主题域，再显式给 `--parent <folder_id>`
    - `subject update <id> --parent <folder_id>` 可以移动到新的父主题域

5. `kanban create <title>` 只创建一个**默认空壳**。
   - 当前稳定命令面没有 `kanban create ... --subject ... --metric ...`
   - create 后要再单独执行 `kanban add-metric`

6. `kanban add-metric <kanban_id> --subject <subject_id> --metric <metric_id>`：
    - `--subject` 用主题域 ID（来自 `subject list/show`）
    - `--metric` 用 `subject list-metrics` 返回的 metric id
    - 不是 fieldName，也不是 `appId:datasetId:fieldName`
    - `kanban add-metric --dry-run` 当前只回显 kanban / subject / metric id，不会提前算出自动布局位置，也不会提前展示默认图表类型
    - CLI 会先读取当前 kanban，再自动找下一个可用布局位置，把该指标生成一个 chart layout
    - 如果 metric id 不在该主题域里，CLI 会提示先跑 `hbi subject list-metrics <subject_id>` 核对可用 id

7. `kanban add-metric` 会优先沿用该业务指标的默认图表类型。
    - 如果 measure 自带 `defaultChart.defaultChartType`，就沿用它
    - 否则回退到 `KPI`

8. `kanban export <id>` 是资源级异步导出命令。
    - 文件输出路径走 `--output-file`
    - 全局 `-o/--output` 仍然只表示 `json|yaml|table` 输出格式，不是导出文件格式
    - 可选的 `--file/--value` 是 export payload 覆盖；如果不传，CLI 会从现有 kanban layouts 自动生成安全的 `chartOptions + chartNames`
    - `--dry-run --output json` 时会返回结构化预览：
      - `method = POST`
      - `path = /kanbans/{id}/async-download`
      - `pollPath = /kanbans/{id}/poll-download`
      - query 里固定会带 `type=xlsx` 和 `timeout=170000`
    - 如果 kanban 还是空壳、没有 layouts，CLI 不会因为“没图表可导出”直接报错；默认 body 会是空对象版的 `chartOptions + chartNames`

## 常用命令入口

`hbi subject --help`：

- `list`
- `show`
- `create`
- `update`
- `delete`
- `add-metrics`
- `remove-metrics`
- `toggle-online`
- `list-metrics`
- `tokenize`

`hbi kanban --help`：

- `list`
- `show`
- `create`
- `update`
- `delete`
- `duplicate`
- `add-metric`
- `export`

## 常见操作

### 先把业务指标挂到主题域

```bash
hbi subject list --output json
hbi subject create "北区经营分析"
hbi subject add-metrics 12 3034:4:m1,3034:4:m2
hbi subject list-metrics 12 --limit 5 --output json
hbi subject toggle-online 12 3034:4:m1,3034:4:m2 --online
hbi subject tokenize 12
```

规则：

- `add-metrics` / `remove-metrics` / `toggle-online` 吃的是 `appId:datasetId:fieldName`，不要传 metric id。
- 即使 `subject list-metrics` 已经返回了某条指标的 `id`，这个 id 也不能直接回填给 `remove-metrics` / `toggle-online`。
- `toggle-online` 必须显式写 `--online` 或 `--offline`。
- 如果用户说“把这个业务指标挂到主题域”，默认先确认 subject id，再拼 metric spec 字符串。
- 如果用户问“这个主题域有多少业务指标”，执行 `hbi subject list-metrics <subject_id> --limit 5 --output json`，读取 `total`，只返回计数和少量样例；不要使用 `--all`。
- `subject tokenize` 触发的是主题域 AI 分词 / 向量化任务；查看进度回到 `hbi scheduler list --entity-group ai-rag-measure-subject-tokenize`。

### 再把主题域指标加到分析看板

```bash
hbi kanban create "北区经营总览"
hbi subject list-metrics 12 --limit 5 --output json
hbi kanban add-metric 88 --subject 12 --metric 456
hbi kanban show 88 --output json
hbi kanban duplicate 88 --title "北区经营总览（副本）"
```

规则：

- `kanban create` 只建空壳；真正挂指标靠 `kanban add-metric`。
- `kanban add-metric` 的 `--metric` 来自 `subject list-metrics` 返回的 `id`。
- `kanban add-metric --dry-run` 只会回显 ids，不会提前告诉你 x/y/w/h 和图表类型；这些是在真实执行时计算的。
- 如果 measure 没有 `defaultChart.defaultChartType`，CLI 会把新 layout 的 `defaultChartType` 回退成 `KPI`。
- 如果 `kanban add-metric` 找不到 metric，先回到 `subject list-metrics <subject_id>` 重新核对。
- 如果用户想做常规 dashboard 样式编排，或只是要把主题域指标放进普通 dashboard chart，不要留在 `kanban`，转 `hbi-dashboard`。

### 把主题域指标放进普通仪表盘

```bash
hbi subject list-metrics 12 --limit 5 --output json
hbi element chart create --dashboard 44 --app 3034 kpi --measure-subject 12 --subject-measure 456
```

规则：

- 这里仍然先用本技能确认 subject 和 subject metric id。
- 真正创建普通 dashboard 图表时切到 `hbi-dashboard`。
- `--subject-measure` 用 `subject list-metrics` 返回的 `id`；不是 `add-metrics` 的 `appId:datasetId:fieldName`。

### 导出分析看板数据

```bash
hbi kanban export 88 --output-file kanban-88.zip
hbi kanban export 88 --file export-payload.yaml --dry-run
```

规则：

- 导出文件路径走 `--output-file`，不要写成全局 `--output xlsx`。
- 如果只想让 CLI 按当前看板内容安全导出，不需要自己手写 payload。
- 只有在确实要覆盖 `chartOptions` / `chartNames` 时，才传 `--file` / `--value`。
- 空 kanban 做 `export --dry-run --output json` 时，默认预览 body 仍是：
  - `chartOptions: {}`
  - `chartNames: {}`

## 推荐工作流

1. 先在 `hbi-data` 里确认 measure 已经存在（`measure list/show`）。
2. 用 `subject list/create` 定位或新建主题域。
3. 用 `subject add-metrics` 把业务指标挂到主题域。
4. 用 `subject list-metrics` 看挂载结果，并拿到 metric id。
5. 用 `kanban create` 建一个空分析看板。
6. 用 `kanban add-metric --subject --metric` 自动布局加指标。
7. 用 `kanban show` / `kanban export` 做查看与导出。
8. 需要共享时，再切到 `hbi-permission` 做 `authorize grant kanban ...`。

## 何时转到别的技能

- 要创建/修改 `measure` 本身，或补数据集/数据模型前置条件：转 `hbi-data`
- 要写复杂公式 / HQL / HE：转 `hql-expert`
- 要做普通仪表盘、页面布局、图表/过滤器控件，或把主题域指标作为普通 dashboard chart 数据源：转 `hbi-dashboard`
- 要做 kanban / subject 的授权：转 `hbi-permission`
- 要描述跨域完整链路（measure -> subject -> kanban -> permission）：转 `hbi-workflow`

## 禁止事项

- 不要把 `subject add-metrics` 写成 metric id 列表。
- 不要把 `kanban add-metric --metric` 写成 fieldName 或 `appId:datasetId:fieldName`。
- 不要编造 `kanban create <title> --subject ... --metric ...` 这种一步完成的命令形态。
- 不要把 `kanban` 当成普通 `dashboard` 的别名。
- 不要把普通 dashboard chart 的 `--measure-subject` / `--subject-measure` 误当成 `kanban add-metric`；它们创建的是 dashboard chart，不是分析看板 layout。
- 不要默认 `subject toggle-online` 不带 flag 就表示 offline。
- 不要继续使用旧 `download` 或全局 `--output xlsx` 来导出 kanban 文件。
