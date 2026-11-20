# Semantic binding

root context 的 `fields` 与 `metrics` 是事实来源。relation hint 只用于判断应该扩展哪一个 relation，不是完整 schema。需要 relation 字段时：

```bash
hbi chatbi context --app <app_id> --dataset <dataset_id> \
  --relation <relation_dataset_id> --delta --output json
```

root reference 写 `{field}`；relation reference 使用 `relationDetails.fieldReference`，不得把 `joinDatasetId` 当 HQL 前缀。

用户请求的实体名若与 root field 的 `fieldName` 或 `label` 精确匹配，优先绑定该 root field，即使它是数字 ID 或编码字段。relation 上的展示字段只有在用户明确说“名称/name/店铺名称/商品名称”等展示属性，或 root 没有精确实体字段时才替代。例如用户问“哪些店铺”且 root 有“店铺”字段，不要自动改成 relation 的“店铺名称”。

按实体分析时要区分身份键与展示名称。若 context 暴露了同一实体的 ID/编码和关联名称，且 source contract 没有保证名称唯一，应以 ID/编码保留查询粒度，尤其是同时按月份分组、比较目标值或使用 `--having` 时；不能只按可能重复的名称聚合，否则不同实体会合并。名称可用于展示，但名称可能重复时，结果还要保留 ID/编码或其他区分信息。按目标值筛选分组结果时，应在实体 ID 与请求时间粒度上分别聚合实际值和目标值，再在同一粒度用 `--having` 比较（例如 `sales > target`），不能先合并同名实体再比较总额。

每个显式 literal 分开处理。地点已命中一个 relation，不表示另一个裸露组织/品牌/成员也属于该 relation。对未标注的组织或实体，先检查其他 relation hint 的直接名称字段，再考虑 group/brand/type。不得用行业常识把用户文本改为邻近分类值。

在澄清前，对每个未绑定的命名 literal 运行：

```bash
hbi data-model value-search --app <app_id> --dataset <dataset_id> \
  --exact --query "<原始 literal>" --output json
```

只有 context 已确定候选字段时才能加 `--candidate-field`。省略它会进行有界、程序化的文本字段等值探测；返回的 `schema` 是可直接用于 query 的真实匹配字段。复合名称必须整段搜索，例如 `华住托管`，不能先搜“华住”再把结果绑定到酒店集团。

exact 没有 canonical match 时，代码/编号类 literal 先尝试一次 `value-search --prefix`（如 `600519` → `600519.SH`），再对**同一整段原始 literal**运行一次普通 `value-search`；结果 `coverage=partial` 只表示被截断，不是不存在。若它返回 canonical `schema` 与 `value`，用该完整 value 作为最终等值条件。普通 fuzzy `value-search` 的 `unmatchedQueries` 仅表示候选查询未命中，绝不是 absence evidence。

若两次 value-search 都未给出 binding，但 relation hint 中存在与 literal 后缀语义一致的候选字段，先扩展该 relation detail，再做一次有界候选 query。只允许移除 literal 与目标 field label **共同结尾**的通用分类后缀，并要求剩余词干与一个完整候选值完全相等；不得拆词、做包含匹配或按行业常识挑选候选。例如 `华住集团` 对 relation field `酒店集团`，可验证候选完整值 `华住`，但不能把 `华住托管` 任意截成 `华住`。

```bash
hbi chatbi context --app <app_id> --dataset <dataset_id> \
  --relation <relation_dataset_id> --delta --output json

hbi data-model query --app <app_id> --dataset <dataset_id> \
  "COUNT({known_non_null_field})" \
  --by "candidate=group({{relation_dataset_id}}.{candidate_field})" \
  --sort value:desc --limit 100 --output json
```

`known_non_null_field` must be replaced with a field from the already-read root/relation
context (for example an order id); do not use `COUNT(*)` unless a real query has
already verified that the current backend accepts it.
候选 query 必须带上已绑定的时间和其他范围条件；只有一个完整候选通过词干全等时，才可在最终 evidence query 中用该 relation `fieldReference` 加等值 `--where`。多个候选、没有候选，或最终 query 无法执行时才澄清。

若 field description 明确说明“未特别说明时使用本字段”或同义约定，它高于字段名直觉，是默认时间口径。GMV、支付金额、支付完成、订单数、入店、离店等指标或事件词不能覆盖这个默认声明；所有日期 filter、period comparison 和时间 `--by` 都使用默认时间字段。若没有这种语义证据且只剩一两个合理时间字段，分别运行最小 query；在有结果能够回答时停止，不要先澄清。

最终 query 必须覆盖每个时间、地点、命名成员、组织/品牌、指标和分组。单一命名实体是 `--where` 约束，不是 `--by` 维度，除非用户明确要求按它展开。每个 `--expr`、`--by`、`--sort`、`--having` uid 使用短 ASCII 标识符；普通维度使用 `group(...)`，时间维度使用实际 HQL。uid 只是查询身份，不是展示名：派生公式没有数据集 label，必须用 `--expr-label UID=TEXT` 提供用户语言的可读名（见 [period-comparison.md](period-comparison.md) 的“输出显示名”）。成员比较在 query 中以条件聚合和 `--having` 完成，不要将多行结果留给回答文本自行比较。
