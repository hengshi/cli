---
name: hbi-data-modeling
description: "数据建模技能。凡是用户提到数据模型、联表、join datasets、事实表、维表、星型模型、关系验证、cardinality、`hbi data-model`、`show`、`tree`、`suggest-joins`、`join-add`、`join-list`、`join-delete`、`query`，或希望让 Agent 判断如何把多个数据集连成可查询模型并验证结果时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi data-model --help"
---

# HBI Data Modeling

> 前置：先读 `hbi-core` 和 `hbi-data`。表达式设计再转 `hql-expert`。

## 这个技能负责什么

本技能负责把“多个数据集”变成“可查询的数据模型”。重点不是写 HQL，而是：

- 选哪一个数据集做主表
- 哪些数据集适合做维表或补充表
- 用什么 join type
- 用什么键去连
- 连完之后怎么验证结果

## 当前 CLI 的稳定入口

`hbi data-model --help` 下常用入口：

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

## 先收集这些信息

开始建模前，至少确认：

- `app_id`
- 主数据集 `dataset_id`
- 候选联表数据集 ID
- 候选 join 键的字段名和类型
- 业务语义：保留主表全部记录，还是只保留匹配记录

推荐起手命令：

```bash
hbi dataset show --app <app_id> <dataset_id>
hbi dataset preview --app <app_id> <dataset_id>
hbi data-model show --app <app_id> --dataset <dataset_id>
hbi data-model tree --app <app_id> --dataset <dataset_id>
hbi data-model preview --app <app_id> --dataset <dataset_id>
```

## `show` / `join-list` / `tree` / `query` 各看什么

- `show`：看当前 dataset 详情和已挂上的 join 摘要。
- `join-list`：看具体 join 行、join id、condition、cardinality；删除 join 时先从这里拿 `join_id`。
- `tree`：看关系图，适合快速理解当前 dataset 连出去和连进来的结构。
- `query`：用临时聚合查询验证“联完后结果是否合理”，不是行级明细投影器。
- `lineage`：看更宽的上下游 lineage，不等于当前 data-model 关系树。

## 建模工作流

### 1. 选主表

优先把“事件/事实”更完整、行数更多、需要保留全部记录的一侧当主表。

常见例子：

- 订单表做主表，客户表做维表
- 销售流水做主表，区域表做维表

### 2. 找候选 join 键

先人工比对字段名、类型、空值情况，不要直接相信字段名像就一定能连。

重点排查：

- 是否真的是同一业务主键
- 类型是否兼容
- 是否存在大量空值
- 是否可能一边唯一、一边重复

### 2.5 先按 base dataset 视角说 cardinality

这里的 many-to-one / one-to-many，默认都相对于 `join-add --dataset <base_dataset_id>` 这侧来说：

- base 多、join 侧一：这是基表视角的 **many-to-one**，最像事实表补维表
- base 一、join 侧多：这是基表视角的 **one-to-many**，会复制 base 行，先确认这是不是你要的
- 两边都重复：这是 **many-to-many**，不要直接 `join-add`

如果你一开始就说不清 cardinality，或者只能靠 `order_id + sku_id` 这类复合键才能准确连上，先不要建 join。

### 3. 把 `suggest-joins` 当成提示，不要当成自动建模器

```bash
hbi data-model suggest-joins --app <app_id> --dataset <dataset_id>
```

当前实现更接近“字段提示”，不是带评分的自动 join planner。它可以帮你缩小排查范围，但不能替代人工判断。

### 4. 选择 join type

默认经验：

- `left`：主表记录必须保留时优先使用
- `inner`：只想保留匹配记录时使用
- 其他 join type（如 `right` / `full` / `cross` / `leftloop`）：只有在你明确知道业务语义时再用

如果你不能清楚回答“未匹配的主表记录是否应该保留”，先不要建 join。

### 5. 创建 join

```bash
hbi data-model join-add \
  --app <app_id> \
  --dataset <base_dataset_id> \
  --join-dataset <join_dataset_id> \
  --type left \
  --on customer_id

hbi data-model join-add \
  --app <app_id> \
  --dataset <base_dataset_id> \
  --join-dataset <join_dataset_id> \
  --type left \
  --on order_customer_id=customer_id

hbi data-model join-add \
  --app <app_id> \
  --dataset <base_dataset_id> \
  --join-dataset <join_dataset_id> \
  --type left \
  --condition "{{<base_dataset_id>}}.{order_id} = {order_id} AND ({{<base_dataset_id>}}.{sku_id} = {sku_id} OR {{<base_dataset_id>}}.{legacy_code} = {legacy_code})"
```

## 当前实现的关键限制

1. `join-add` 现在有两条 authoring lane：
   - 简单单字段对：`--on`
   - 多条件 / 混合 `AND` / `OR` / 更复杂逻辑：`--condition "<HQL>"`

2. `join-add --on` 只支持两种单字段写法：
   - 同名字段简写：`customer_id`
   - 显式左右映射：`order_customer_id=customer_id`

3. 如果要多字段复合 join，不要重复传两个 `--on`。
   当前正确做法是改走 `--condition`，直接写 HQL 表达式。
   - 推荐主数据集侧写成 `{{base_dataset_id}}.{field}`
   - join-dataset 侧直接写裸 `{field}`
   - 如果你显式写了 `{{join_dataset_id}}.{field}` 或 `{{join_dataset_title}}.{field}`，CLI 会归一成 join 侧裸字段，和前端保存语义对齐

4. `--on` 的字段名当前会先做规范化。
   - `--on customer_id`
   - `--on {customer_id}`
   - `--on {order_customer_id}={customer_id}`
   这些花括号写法都会被 CLI 去掉外层 `{}` 再校验字段名。

5. 如果数据集 schema 可用，CLI 会先校验 `--on` 里的字段名再发请求。
   `--condition` 走 formula 路径，不会像 `--on` 一样逐字段预检；所以技能里不要编造字段名，最好先 `dataset fields` / `data-model show` 确认。

6. `suggest-joins` 不是 authoritative planner。
   它只能提供弱提示，不能代替 cardinality 判断。

7. `data-model` 这组命令当前**没有实现真正的 dry-run 预览**。
   全局 `--dry-run` 不能当成 join-add / join-delete 的安全护栏；更稳的做法是：
   - 变更前先 `show` / `tree` / `preview`
   - 每次只加一个 join
   - 变更后立刻 `join-list` / `tree` / `preview` / `query` 验证

8. 一次只加一个 join，并且每加一次就验证。

9. `join-delete` 只接受 `--join-id`，不是按 dataset pair 删除。
   先 `join-list` 找 id，再删。

10. `join-add --type` 的稳定 join type 规范值是：
   - `left`
   - `right`
   - `inner`
   - `full`
   - `cross`
   - `left-loop`
   其中 loop join 还接受 `left_loop_join` / `left loop join`，但**不要编造成 `leftloop`**。

11. `data-model query` 走 chart-data 同款分析查询路径，不是旧的 JSON `--he`。
   当前数据集字段写 `{field}`；联表字段如果字段名在所有 join 关系里唯一，也可以直接写 `{field}`，CLI 会自动改写成 relation-qualified 引用；分组用重复的 `--by`，过滤用重复的 `--where`，聚合后过滤用重复的 `--having`。
   旧的单个位置参数 HQL 仍兼容，并等价于输出 uid 为 `value` 的单指标表达式。新查询优先使用显式 uid：
   - `--expr sales="SUM({amount})"` 会生成一个输出 uid 为 `sales` 的度量轴
   - `--expr orders="COUNT(*)"` 可和其它 `--expr` 重复传入，形成多指标结果
   - `--by region="group({region})"` 会生成一个输出 uid 为 `region` 的分组轴
   - `--by group({region})` 会变成 `group({{dataset_id}}.{region})`，uid 是 `region`
   - `--by month({created_at})` 会变成 `month({{dataset_id}}.{created_at})`，uid 是 `created_at_month`
   - 联表字段会使用 `join-list` 里 `datasetId` 暴露的 relation dataset id，例如 `{{relation_dataset_id}}.{brand_name}`；不要用原始 `joinDatasetId` 当查询前缀。
   - 如果多个联表都有同名字段，CLI 会要求显式写 `{{relation_dataset_id}}.{field}`。
   - `--sort <uid>[:asc|desc]` 支持按任意输出 uid 排序；显式 uid 时 Top 1/最大值应写 `--sort sales:desc --limit 1`，旧位置参数写法则仍用 `--sort value:desc --limit 1`。
   - `--having "sales > 1000000"` 表示聚合后过滤，引用的是输出 uid，不是原始字段；不要把聚合后过滤塞进 `--where`。
   - `--explain --output json` 只输出编译后的 chart-data request，不执行查询，适合调试和 eval 对比。
   不要把没有 `--sort` 的裸 `--limit 1` 当成 Top 1。

12. `--where` 有两条解析路径：
   - 简单条件（如 `{id} > 0`）会被解析成结构化 HE function
   - 复杂条件会退回 formula；这时 CLI 会把当前数据集裸字段改写成 `{{dataset_id}}.{field}`，把唯一联表裸字段改写成 `{{relation_dataset_id}}.{field}`，已经带前缀的 `{{orders}}.{field}` 会原样保留

13. JSON 输出形态是稳定可脚本化的：
   - `show --output json`：`{ dataset, joins }`
   - `preview --output json`：`{ schema, data }`
   - `tree --output json`：`{ root: { ..., children: [...] } }`
   - `lineage --output json`：对象，不是数组

14. many-to-many 不是“再大胆一点也许能过”的场景。
   如果桥表还没准备成可用 dataset，先回 `hbi-data` 做 bridge / fusion / 上游整形，再回来建模。

## 验证顺序

创建 join 后按这个顺序验证：

```bash
hbi data-model join-list --app <app_id> --dataset <base_dataset_id>
hbi data-model tree --app <app_id> --dataset <base_dataset_id>
hbi data-model preview --app <app_id> --dataset <base_dataset_id> --limit 20
hbi data-model query --app <app_id> --dataset <base_dataset_id> "COUNT({id})"
hbi data-model lineage --app <app_id> --dataset <base_dataset_id>
```

验证重点：

- join 是否真的出现在列表里
- tree 里的关系结构是否符合预期
- 行数是否异常膨胀
- 是否出现明显重复
- 关键指标是否比 join 前失真

如果要做按维度聚合验证，优先像下面这样写：

```bash
hbi data-model query \
  --app <app_id> \
  --dataset <dataset_id> \
  --expr sales="SUM({amount})" \
  --by region="group({region})" \
  --by month_created_at="month({created_at})" \
  --where "{status} = 'completed'"
```

## 建模时的启发式规则

这些规则来自通用数据建模经验，但必须服从当前 CLI 的限制：

1. 事实表做主表，维表做 join_dataset。
2. 不清楚业务语义时，先从 `left join` 开始推演。
3. 看到多对多迹象时，不要直接建模，先判断是否需要桥表。
4. 从 base dataset 视角说清 many-to-one / one-to-many，避免把方向说反。
5. 桥表存在时，也是一条 join 一条 join 地加，不要一次把整张图全挂上去。
6. 同一个模型里不要连续加多个未验证 join。
7. 在模型还没验证前，不要急着继续写 `measure`、图表或 dashboard plan。

## 什么时候必须停下来问用户

以下情况不能靠猜：

- 有多个候选 join 键
- 需要复合键才能准确连
- 左右字段名不同
- cardinality 不清楚
- 可能存在历史快照 / 软删除 / 多版本记录
- 多对多关系存在，但桥表还没准备成可用 dataset
- 业务上到底要保留哪一侧记录不明确

## 与其他技能的边界

- 还在找 connection / dataset：转 `hbi-data`
- 多对多建模需要先补桥表、去重表、融合表或其他派生 dataset：先回 `hbi-data`
- 想产出新的融合数据集，而不是给现有模型补关系：回 `hbi-data`，走 `dataset create-fusion`
- 已经开始写表达式或聚合：转 `hql-expert`
- 建模只是完整工作流的一步：转 `hbi-workflow`

## 禁止事项

- 不要把 `suggest-joins` 说成自动建模能力
- 不要假设 `join-add` 已支持多字段复合 join 或任意复杂表达式映射
- 不要把 many-to-one / one-to-many 的方向说成“跟谁唯一就算谁”，一定要说清楚是相对于 base dataset
- 不要把 `join-delete` 说成能直接按 join_dataset / dataset pair 删除
- 不要把 `data-model query` 说成旧的 JSON `--he` authoring 或逐行明细投影接口
- 不要把裸 `data-model query --limit 1` 说成按度量取 Top 1；必须显式配合 `--sort <metric_uid>:desc` 才表示按聚合值取最大。旧位置参数 HQL 的默认 metric uid 是 `value`
- 不要把裸 `{region}` 当成推荐 `--by` 写法；普通维度要显式写成 `group({region})`
- 不要继续推荐 `created_at:month` / `region:none` 这类旧 shorthand；统一改成 `month({created_at})` / `group({region})`
- 不要在 join 未验证前继续生成复杂指标和仪表盘
- 不要用“LLM 可能知道行业规律”替代对字段和 cardinality 的核查
