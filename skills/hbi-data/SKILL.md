---
name: hbi-data
description: "数据领域技能。凡是用户提到数据连接、数据集、字段、数据集导入/引用/融合、dataset schedule、expression-rewrite、指标、业务指标、预览、HQL/HE 查询，或需要走 connection→dataset→data-model→metric/measure 这条链路时，都应该使用本技能。明确进入联表设计、主表/维表判断、join 关系验证、data-model tree/join-add 时转 hbi-data-modeling；明确做 pipeline 节点编辑时转 hbi-pipeline，明确做 notebook 段落与执行时转 hbi-notebook。复杂公式再切到 hql-expert。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi connection --help"
---

# HBI Data

> 前置：先读 `hbi-core`。复杂 HE/HQL 表达式再转 `hql-expert`。
>
> 需要精确的资源名、产品术语、`metric` / `measure` 边界时，先读 `references/terminology.md`。
>
> 需要把 CLI dataset 入口和前端“数据集类型”中文名对齐时，继续读 `references/dataset-types.md`。
>
> 需要写 `dataset create-api/update/replace/export` 的 `--file/--value` 载荷，或给 `metric` / `measure` 写 `--display-format` JSON 时，继续读 `references/payload-contracts.md`。

## 数据领域术语

精确术语与别名以 `references/terminology.md` 为准；这里只强调最容易混淆的一点：

- `metric` = 原子指标
- `measure` = 业务指标
- 不要把前端图表/数据集界面里的“度量 / Metric”显示词误当成 CLI `measure` 命令边界
- `dataset` / `data-model` / `metric` / `measure` 这类命令里的 `--app` 往往是承载数据集的数据包（`data-app`）ID；当前数据包应优先创建和检索在 `data-mart`

## 常用命令入口

### 数据连接

`hbi connection --help` 常用子命令：

- `types`
- `list`
- `show`
- `test`
- `create`
- `delete`
- `update`
- `browse`
- `query`

### 数据集

`hbi dataset --help` 常用子命令：

- `list`
- `show`
- `fields`
- `preview`
- `export`
- `knowledge`
- `example`
- `create`
- `update`
- `replace`
- `create-from-file`
- `upload`
- `create-api`
- `create-custom-sql`
- `create-reference`
- `create-union`
- `create-fusion`
- `create-aggregate`
- `create-pivot`
- `create-unpivot`
- `delete`
- `column-*`
- `column-order`
- `column-groups-apply`
- `column-copy-as`
- `column-value-group-*`
- `column-json-split-*`
- `granularity-*`
- `status`
- `schedule`
- `duplicate`
- `import`
- `lineage`
- `expression-rewrite`

`dataset granularity-create` 当前按前端粒度管理 body 对齐：

- 请求体字段是 `where`，不是 `whereClause`
- 未显式传 `--dimensions` 时，CLI 会自动把 `--time-field` 补进 dimensions，避免造出前端不消费的粒度 shape
- 默认会带空的 `where: []` / `metrics: []`，这样 Web 粒度管理页拿到的是稳定数组字段

### 数据模型

`hbi data-model --help` 常用子命令：

- `list`
- `show`
- `preview`
- `query`
- `tree`
- `lineage`
- `suggest-joins`
- `join-add`
- `join-list`
- `join-delete`

### 指标与业务指标

`hbi metric --help`：

- `create`
- `delete`
- `update`
- `list`
- `show`
- `query`

`hbi measure --help`：

- `create`
- `delete`
- `update`
- `list`
- `show`
- `query`

当前 `metric` / `measure` 的稳定 authoring 补充面：

- `--display-format '<json>'`：写资源级 `config.formatter`
  - 外层是 typed map：`config.formatter.<type>`
  - 内层 value 复用 dashboard `axes[].formatter` 那套 flat `DisplayFormatter` leaf；不要把 `{"number": {...}}` 这种 wrapper 直接抄成轴级 `formatter`
  - 完整字段、示例和与 chart axis 的继承关系见 `references/payload-contracts.md`
- `--group sales,core`：写资源级分组，落到 `tags.group[]`
- `measure create/update` 仍兼容旧的 `--tag` 长参数别名，但新写法优先用 `--group`

数量类意图的 agent-safe 规则：

- 用户问“有多少个业务指标 / 指标 / measures / metrics”时，不要执行 `--all` 后把全量列表交给模型数。
- 优先使用分页列表的 metadata：`hbi measure query --limit 5 --output json`、`hbi measure list --app <app> --dataset <dataset> --limit 5 --output json`、`hbi metric list --app <app> --dataset <dataset> --limit 5 --output json`。
- 这些列表默认返回分页 envelope，读取 `total` / `hasMore` / `truncated`，回复计数和少量样例即可；`data` 只当样例，不当完整集合。
- 只有用户明确要求导出或人工确认要看全量明细时，才使用 `--all` 或更大的 `--limit`，并优先配合 `--write-output`。

### 已拆分出去的数据集成与数据科学领域

`hbi pipeline --help`：

- `list`
- `show`
- `create`
- `update`
- `delete`
- `duplicate`
- `status`
- `errors`
- `node`
- `edit`

`hbi notebook --help`：

- `list`
- `show`
- `create`
- `update`
- `delete`
- `paragraphs`
- `add-paragraph`
- `execute`
- `delete-paragraph`

如果用户明确在做下面这些事情，不要继续停留在本技能，直接切专用技能：

- pipeline 生命周期、节点编辑、节点预览、pipeline 调度：转 `hbi-pipeline`
- notebook 段落、connection 授权、paragraph execute、notebook 调度：转 `hbi-notebook`

## 推荐工作流

### 1. 先找数据连接

```bash
hbi connection types
hbi connection list --output json
hbi connection show <connection_id>
hbi connection test <connection_id>
```

### 2. 再找或建数据集

```bash
hbi dataset list --app <app_id>
hbi dataset show --app <app_id> <dataset_id>
hbi dataset fields --app <app_id> <dataset_id>
hbi dataset preview --app <app_id> <dataset_id>
hbi dataset update --app <app_id> <dataset_id> --name "new-title"
hbi dataset expression-rewrite --app <app_id> --dataset <dataset_id> --expression "SUM({amount})"
hbi dataset export --app <app_id> <dataset_id> --output-file dataset.xlsx
```

如果是新建数据集，优先考虑这些入口：

- `create`
- `update`
- `create-from-file`
- `create-api`
- `create-custom-sql`
- `create-reference`
- `import`
- `create-union`
- `create-fusion`

字段与表达式的默认预检顺序：

1. 先 `dataset fields` 看真实字段名、purpose、display format、display value。
2. 再 `dataset preview` 看样例数据是否符合预期。
3. 需要在 dataset 上校验公式时，用 `dataset expression-rewrite`，不要直接跳到 `metric` / `measure`。

字段 schema 更新的当前稳定写面：

- `dataset column-update` 现在只暴露稳定单字段 flags，不再暴露 raw patch 入口
- 字段管理页功能名与 CLI 对照：

| 前端功能名 | CLI surface |
| --- | --- |
| 字段名称 / 显示名 | `dataset column-update --column <field> --label ...` |
| 字段描述 | `dataset column-update --column <field> --description ...` |
| 字段类型 | `dataset column-update --column <field> --type ...` |
| 字段用途 | `dataset column-update --column <field> --purpose ...` |
| 显示 / 隐藏字段 | `dataset column-update --column <field> --visible true|false` |
| 隐藏字段值 | `dataset column-update --column <field> --hide-value true|false` |
| 展示格式 | `dataset column-update --column <field> --display-format ...` / `--clear-display-format` |
| 展示格式 > 空值替换 | `dataset column-update --column <field> --null-replace ...` / `--clear-null-replace` |
| 字段显示值 | `dataset column-update --column <field> --display-value-*` / `--clear-display-value` |
| 列顺序 / 字段顺序 | `dataset column-order --fields ...` |
| 字段分组 | `dataset column-groups-apply --file|--value ...` |
| 复制为 | `dataset column-copy-as ...` |
| 列值分组 / `data_group` | `dataset column-value-group-create|update ...` |
| JSON 拆列 | `dataset column-json-split-show|apply ...` |

- 字段管理页改类型时，写的是 top-level `type`
- `basicType` / `originType` / `nativeType` 更适合作为 `dataset fields` 的读侧输出理解，不要把它们当成稳定 patch 入口
- `--display-format` 对应前端 **展示格式**
- `--display-value-*` 对应前端 **字段显示值**
- `--null-replace` / `--clear-null-replace` 属于 **展示格式** 子能力，不是字段显示值
- 这两层要分开理解：**展示格式**决定值怎么显示，**字段显示值**决定这个字段显示时去引用谁的值
- 非 API dataset 的 `dataset update --file/--value` 仍是 dataset options patch，不负责字段 schema/type 变更；这类变更回到 `dataset column-update`
- `dataset column-order --fields a,b,c,...` 对应前端字段管理页的**列顺序 / 字段顺序**；要求给出**完整字段顺序**
- `dataset column-groups-apply --file|--value` 对应前端字段管理页的**字段分组**
- 如果你真的需要 `column-groups-apply`、`column-value-group-*`、`column-json-split-*` 的 JSON/YAML 输入 shape，再读 `references/payload-contracts.md`，不要在本技能里记低层 request body
- `dataset column-copy-as` 对应字段管理页 **复制为**；只接受带 `expr` 的派生字段，不接受 JSON split child
- `dataset column-value-group-create|update` 对应字段管理页 **列值分组 / data_group**；这是派生字段 authoring，不是 `column-groups-apply`
- `dataset column-json-split-show|apply` 对应字段管理页 **JSON 拆列**；show 先看可拆 key，apply 再提交 `[{ key, label?, fieldName?, type }]`
- 但派生数据集已经不是“任意 options merge”：
  - `fusion`：只允许 `joinOpts` / `schema` / `uid` / `rootDatasetId` / `rootDatasetName` / `where`（CLI 会强制 `updateSchema=true`）
  - `union`：只允许 `unionOptions` / `schema`（CLI 会强制 `updateSchema=true`）
  - `aggregate`：只允许 `rootDatasetId` / `aggregateOptions` / `schema`
  - `pivot` / `unpivot`：只允许 `he` / `schema`
- 这些派生数据集在带 `--file/--value` 更新时，CLI 会改走前端同款 `/apps/{app}/datasets/{dataset}/edit`，而不是继续走 generic PUT merge。
- `fusion` 的公式 `where` 要引用**持久化后的融合字段**（例如 `{id_1}`），不要继续写 source-side `{{123}}.{id}` 这种 dataset-qualified 引用；当前 CLI 会直接拒绝这种 payload。
- 只有**纯重命名**（不带 `--file/--value`）时，派生数据集才继续走轻量 title update。

#### API 类型数据集

```bash
hbi dataset create-api --app <app_id> --name <name> --file api-dataset.yaml
hbi dataset update --app <app_id> <dataset_id> --file dataset-options-patch.yaml
```

- API dataset 现在按前端 `api-query` authoring contract 工作：`--file/--value` 传的是 `path/method/params/headers/pageConfig/authConfig/schema` 这一层，CLI 会归一化成保存时的 `options.{ type: "api", apiOptions, schema }`。
- `create-api` / API 类型的 `dataset update` 都支持 `--import-type 0|1`；如果 payload 显式写了别的 `type`，CLI 会直接拒绝。
- 当 payload 没有显式给 `schema` 时，CLI 会先走 preview，再用 preview 返回的 schema 保存。
- API 类型的 `dataset update` 走前端同款 `/apps/{app}/datasets/{dataset}/edit`；普通 connection/reference/custom-sql 这类非 API dataset 仍走 fetch-and-merge 的普通 PUT 更新路径。
- `dataset update --file/--value` 也接受 `dataset show --output json` 这类带顶层 `options` 的对象；CLI 会自动抽出 `options`。
- 但对派生数据集，不要直接把 `dataset show` 的整份 runtime `options` 原样回灌；应只保留上面列出的稳定 authoring 子集。

#### 数据集知识管理 / 智能学习

```bash
hbi dataset knowledge --app <app_id> --dataset <dataset_id> show --output json
hbi dataset knowledge --app <app_id> --dataset <dataset_id> update --description "..." --weight 8
hbi dataset example --app <app_id> --dataset <dataset_id> create
hbi dataset example --app <app_id> --dataset <dataset_id> show --output json
hbi dataset example --app <app_id> --dataset <dataset_id> update --value "..."
hbi scheduler list --entity-group ai-create-example --output json
```

规则：

- `knowledge` 对应知识管理里的“数据集描述 / 知识权重”；内部字段分别是 `chatDesc` / `chatWeight`。
- `example create` 触发的是 dataset 级 `AI_CREATE_EXAMPLE` scheduler job，不是同步生成；后端会基于系统抽象模板以及数据集字段/字段值/指标生成 dataset-specific HQL examples，任务查看回到 `scheduler`.
- `example show/update` 对应的是“学习结果”读写；内部字段是 `chatExample`。这不是 `UserSystem` 那类 system prompt 字段；后端 `FunctionsSelectorLLM` 会优先使用这份 dataset-specific example pool，再回退到全局 `HQLExamples` / `HQLCoreExamples`。
- 如果用户问的是系统级 ChatBI 配置 / prompt / 向量库初始化，转 `hbi-data-agent`；不要把 dataset knowledge/example 和 `data-agent` 后台治理面混成一层。

#### `create-reference` / `import` / `create-fusion` 的边界

- `create-reference`：在当前 app 创建一个“引用数据集”，继续指向别处已有 dataset。
- `import`：把 `source-app` 里的一个或多个 dataset 导入当前 app，适合批量搬运。
- `create-fusion`：创建一个新的融合数据集；如果用户只是想给现有 data-model 补 join 关系，而不是产出新的派生 dataset，切到 `hbi-data-modeling` 的 `join-add`。

### 3. `dataset schedule` 只负责创建；后续治理转 `hbi-scheduler`

```bash
hbi dataset schedule --app <app_id> --dataset <dataset_id> create --cron "0 0 2 * * *"
hbi scheduler list --entity-group dataset --entity-key <app_id>-<dataset_id> --output json
hbi scheduler update <schedule_id> --disable
hbi scheduler delete <schedule_id>
```

这里的 dataset 调度是 `DATASET` entityGroup，不是 app refresh-schedule。创建入口在 `dataset schedule`，后续查、停用、删除都回到通用 `scheduler`；如果问题已经变成 `schedule_id` / `context_id` 治理，切到 `hbi-scheduler`。

### 4. 如果任务进入联表设计或关系判断，切到 `hbi-data-modeling`

```bash
hbi data-model list --app <app_id>
hbi data-model show --app <app_id> --dataset <dataset_id>
hbi data-model tree --app <app_id> --dataset <dataset_id>
hbi data-model preview --app <app_id> --dataset <dataset_id>
hbi data-model suggest-joins --app <app_id> --dataset <dataset_id>
```

需要 join 设计、主表/维表判断、join type 选择、cardinality 推断、关系验证时，不要停留在本技能，直接切到 `hbi-data-modeling`。

`data-model query` 依然走位置参数 HQL，不是旧技能里写的 JSON `--he` 形式；表达式设计转 `hql-expert`。

### 5. 决定是用 `metric` 还是 `measure`

- 需要普通指标字段、原子计算：优先 `metric`
- 需要业务指标语义、分析维度与主题域：优先 `measure`
- `date_compare` / `previous` 这类同环比函数本身不是“先建 dataset granularity 才能写”的命令前置条件；它们更常依赖下游查询 / 图表提供匹配时间维
- 如果用户要的是“自带时间语义 / 固定维度过滤 / 可复用同比环比对象”，优先 `measure`，不要默认回答成裸 `metric create`
- 如果用户强调“业务指标中心”“主题域指标”“指标看板”，通常还要切到 `hbi-indicator-center`，由它承接 `subject` / `kanban`

## 常用示例

```bash
hbi dataset fields --app <app_id> <dataset_id>
hbi dataset expression-rewrite --app <app_id> --dataset <dataset_id> --expression "SUM({amount})"
hbi dataset column-update --app <app_id> --dataset <dataset_id> --column amount --label "Revenue" --description "gross revenue"
hbi dataset column-update --app <app_id> --dataset <dataset_id> --column amount --display-format '{"number":{"thousands":true,"decimal":2}}'
hbi dataset column-update --app <app_id> --dataset <dataset_id> --column amount --null-replace 0
hbi dataset column-update --app <app_id> --dataset <dataset_id> --column user_id --display-value-dataset 99 --display-value-related-field user_id --display-value-field user_name
hbi dataset column-order --app <app_id> --dataset <dataset_id> --fields order_id,store,amount
hbi dataset column-groups-apply --app <app_id> --dataset <dataset_id> --value '[{"name":"Sales","children":["store","amount"]}]'
hbi dataset column-copy-as --app <app_id> --dataset <dataset_id> --source calc_store --name calc_store_copy
hbi dataset column-value-group-create --app <app_id> --dataset <dataset_id> --column amount --name amount_band --group-type continuous --value '[{"name":"Small","toValue":100,"including":true},{"name":"Large"}]'
hbi dataset column-json-split-show --app <app_id> --dataset <dataset_id> --column payload
hbi dataset column-json-split-apply --app <app_id> --dataset <dataset_id> --column payload --value '[{"key":"user.name","fieldName":"user_name","type":"string"}]'
hbi dataset replace --app <app_id> <dataset_id> --file dataset-replace.yaml
hbi dataset replace --app <app_id> <dataset_id> --source-file ./orders.csv --header-row 0 --force
hbi dataset create-reference --app <app_id> --name <name> --source-app <source_app_id> --source-dataset <dataset_id>
hbi dataset import --app <target_app_id> --source-app <source_app_id> --datasets 11,12
hbi metric update --app <app_id> --dataset <dataset_id> <field_name> --group sales,core --display-format '{"number":{"thousands":true,"decimal":2}}'
hbi measure update --app <app_id> --dataset <dataset_id> <field_name> --group finance --display-format '{"number":{"unit":"万元"}}'
hbi metric list --app <app_id> --dataset <dataset_id>
hbi measure list --app <app_id> --dataset <dataset_id>
```

`dataset import` 当前对齐前端 `ImportDatasetModal`：

- 目标是把**其他应用 / 数据包里的数据集**导入到当前应用。
- 命令面是：
  - `hbi dataset import --app <target_app_id> --source-app <source_app_id> --datasets 11,12`
- 前端当前 source picker 来自个人空间 / 团队空间 / 数据集市树，并通过 `GET /apps/{sourceAppId}/datasets?type=connection` 拉可导入列表；因此这条命令当前应优先理解成**导入 connection-backed 数据集**，不要把它当成任意编辑态数据集结构的通用搬运入口。
- 如果你要的是“继续引用源数据集、不要复制一份”，优先用 `dataset create-reference`，不要误用 `dataset import`。

`dataset replace` 当前先按前端 `replaceDataset` body 做稳定 authoring：

- `--file/--value` 只用于 frontend `replaceDataset` 这条 generic body（reference / existed dataset options / connection / custom SQL）。
- 也支持直接传**裸 `options` object**，CLI 会自动包成 replace request。
- 用本地 Excel / CSV 替换时，不要传 `options.type=upload`；前端真实走的是另一条 `replaceFileDataset` 流程，CLI 对应入口是 `--source-file`（可配 `--sheet-id` / `--header-row` / `--name` / `--connection`）。
- 这是单数据集层面的来源替换；如果用户要批量替换整个应用里的 connection / dataapp，切回 `hbi-app` 的 `connection-replace` / `dataapp-replace`。

## 业务指标与看板的边界

`measure.rs` 源码明确说明：业务指标是“指标中心”范式，和普通图表的字段拖拽范式不同。遇到以下场景要优先切到 `hbi-indicator-center`（再由它落到 `subject` / `kanban`）：

- 主题域里的业务指标上墙
- 指标中心分析
- 多个业务指标组合看板

## 使用规则

1. 先 `connection`，再 `dataset`，再 `data-model`，最后才是 `metric` / `measure`。
2. 字段名、display format、display value、dataset 公式校验，优先走 `dataset fields` + `dataset expression-rewrite`。
3. 需要“新的融合数据集”时留在 `dataset create-fusion`；需要“现有 model 上补 join”时切到 `hbi-data-modeling`。
4. `dataset schedule` 只负责创建，后续调度治理回 `hbi-scheduler`。
5. 需要联表建模时，先切到 `hbi-data-modeling`，不要只靠通用数据技能硬推 join。
6. 需要复杂公式时，不在本技能里硬写，转 `hql-expert`。
7. 明确做 pipeline 节点或 schedule 时，转 `hbi-pipeline`。
8. 明确做 notebook paragraph / execute / connection / schedule 时，转 `hbi-notebook`。
9. 需要跨资源编排时，转 `hbi-workflow`。

## 禁止事项

- 不要把 `metric` 当成 `measure` 的同义词。
- 不要在没有 `--app` 的情况下套用旧数据集示例。
- 不要在未验证连接可用性前直接创建依赖它的数据集。
- 不要把 `create-reference`、`import`、`create-fusion` 混成同一种“复用数据集”动作。
- 不要把 dataset schedule 后续的停用/删除还留在 `dataset schedule` 命令族里硬猜。
- 不要继续把 pipeline / notebook 细节硬塞在通用数据技能里。
- 不要假设 `pipeline` 能替代 `dataset` / `data-model` 建模能力。
