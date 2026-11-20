# Period comparison

先查看 root context 的 `queryCapability.functionCatalog.periodComparison.recipes`。只有 `status = supported` 的 recipe 可进入最终 query：

- 上期值：`previous`
- 同比/环比增量：`previous_growth`
- 同比/环比增长率：`previous_growth_rate`

recipe 的 metric 使用真实聚合表达式，time field 必须来自 context authority。最终 query 只过滤用户请求的本期报告区间；不要手写当前期与上期 helper query，再由回答文本计算比较。

中文问法按结果单位区分：

- “<指标>及其同比/环比”“<指标>和同比/环比”“分别是多少”没有出现增长、增加、减少、变化、率、百分比等结果单位时，返回本期指标和上期/同期指标值，使用 `previous`；不得默认改成增长率。
- “比较 A 与上期/前一个月/去年同期的 <指标>”“分别是多少”“本期和上期的 <指标>”要求两期指标值，使用 `previous`，最终输出当前值和上期值；不得把它改写成增量。
- “增长多少 / 增加多少 / 减少多少 / 变化多少”未出现比例词时，返回绝对增量，使用 `previous_growth`。
- “增长率 / 增幅 / 百分比 / 比例”才返回比例，使用 `previous_growth_rate`。

HQL literal 始终使用单引号。以下示例明确要求本期订单数和月环比绝对增量，`'<period>'` 不是 shell quoting：

```bash
hbi data-model query --app <app> --dataset <dataset> \
  --expr orders="count({订单号})" \
  --expr delta="previous_growth(count({订单号}), 'month', 1, {入店日期})" \
  --expr-label delta="订单数环比增量" \
  --by city="group({城市})" --by month="month({入店日期})" \
  --where "{入店日期} >= '2024-03-01' AND {入店日期} < '2024-04-01'" \
  --sort orders:desc --limit 1 --evidence --output json \
  | hbi chatbi compose --app <app> --dataset <dataset> \
      --select city --select month --select orders --select delta \
      --order city --order month --order orders --order delta \
      --diagnostics --intent-value '{"requiredOutputs":["city","month","orders","delta"]}' \
      --input - --output json
```

`month`、日期和成员值在 HQL 内都不能写为双引号。若由 context 提供的 recipe 首次失败，先检查 literal 和 field reference 的转义；不要改成两条 query 后在文字答案中自行相减。

## Final projection invariant

`previous` / `previous_growth` / `previous_growth_rate` 会由引擎在最终 query 内解析基期。因此最终 query 的 `--where` **只能**覆盖用户请求的本期，不能为了展示或计算基期而扩展到本期之前：

- 保留当前时间 bucket，例如 `--by year="year({日期})"`；
- 不要在终态加入单独的 `previous(...)` 基期 output，除非用户明确要求基期值；
- compose 的 `--select` / `--order` 只保留用户请求的维度、本期时间和所需的 comparison output；本期指标只有在用户明确要求，或 bare “<指标>及其同比/环比”需要同时展示本期指标时才保留。

本期时间 bucket 必须保留在 query 的 `--by` 中。chart 是否展示当前时间 bucket 取决于问题主语：固定期间内“哪个实体最高/最低/增长最快”只需要实体和 comparison metric；“哪些/有哪些/哪几个/前 N/列表”或明确要展示期间时，输出当前时间 bucket。若同一句同时出现“增长率最快/最高/最低”和“哪些/有哪些/哪几个”，不要把它改写成单数“哪个”；即使 `--limit 1`，最终 compose 仍选择实体、本期时间 bucket、comparison metric。

当问题同时要求本期指标和环比/同比/上期比较值时，本期 time bucket 是解释 comparison 的必要列，即使问题看起来是固定期间 Top 1。投影顺序为实体维度 → 当前 time bucket → 本期指标 → comparison metric。若问题是英文 `from <previous period> to <current period>` / `in <current period>` 或强调期间本身，并且只展示 comparison metric，则投影顺序为当前 time bucket → 实体维度 → comparison metric。

例如“2023 年相对 2022 年增长率最高的商品”终态筛选应是 `"{日期} >= '2023-01-01' AND {日期} < '2024-01-01'"`，而不是同时查询 2022 与 2023。`previous_growth_rate(..., 'year', 1, {日期})` 仍会得到 2023 相对 2022 的结果。

当一个 evidence query 已返回非空的“请求维度 + 当前时间 bucket + comparison 结果”时，它就是终态证据：立刻重跑**同一条**命令并直接 pipe 给 compose。不要为了“简化”而删除时间 bucket 再查询；`previous_*` 缺少时间 bucket 时通常会变成 `null`，即使前一条查询已经正确。

年度筛选默认使用半开区间：

```text
{日期} >= '2024-01-01' AND {日期} < '2025-01-01'
```

`year({日期})` 返回的是按年归桶后的日期值（例如 `2024-01-01`），不是整数 `2024`。因此不要写
`year({日期}) = 2024`，这会触发日期与数字的类型转换错误。优先使用上面的半开日期区间；如果确实要按年比较，使用同类型的日期表达式，例如：

```text
year({日期}) = year('2024-01-01')
```

若用户未指定时间字段，先遵从 dataset/field description；只剩一两个合理候选时，分别跑有界 query 并在证据足够时停止 fan-out。

若最终 query 需要 helper 输出验证，compose 使用 `--select` 仅保留用户要求的列。对“增长率最快的商品”这类 comparison-only 问题，第一条 query 就应保留 `year({日期})` 的当前时间 bucket；即使 query 同时计算 `sales`，终态也应显式投影为：

```bash
hbi data-model query --app <app> --dataset <dataset> \
  --expr sales="sum({销量})" \
  --expr growth_rate="previous_growth_rate(sum({销量}), 'year', 1, {日期})" \
  --expr-label growth_rate="销量同比增长率" \
  --by item="group({商品})" --by year="year({日期})" \
  --where "{类目} = '目标类目' AND {日期} >= '2023-01-01' AND {日期} < '2024-01-01'" \
  --sort growth_rate:desc --sort item:asc --limit 1 --evidence --output json \
  | hbi chatbi compose --app <app> --dataset <dataset> \
      --select item --select year --select growth_rate \
      --order item --order year --order growth_rate \
      --diagnostics --intent-value '{"requiredOutputs":["item","year","growth_rate"],"helperOutputs":["sales"]}' \
      --input - --output json
```

`sales` 在这里是 query helper，不是用户请求的输出；不要依赖 compose 的默认全列行为。

query 的 `--sort growth_rate:desc` 决定排序。compose 的 `--order` 只传裸 uid 用于输出列顺序；不要写 `--order growth_rate:desc`。

## Comparison presentation

period comparison 的输出列必须显式白名单，不要依赖 compose 默认全列：

- bare “<指标>及其同比/环比”：请求实体维度 → 当前时间 bucket → 本期指标 → `previous` 结果；
- “增长多少/增加多少/减少多少/变化多少”：请求实体维度 → 可选当前时间 bucket → `previous_growth` 结果；
- “增长率/增幅/百分比/比例”：请求实体维度 → 可选当前时间 bucket → `previous_growth_rate` 结果；
- 单一最高/最低实体比较（“哪个品牌同比最大”“哪个商品增长最快”）：实体 → comparison metric；若用户明确要求显示期间，或被选出的实体本身是月份/日期，才加当前时间 bucket；
- 多实体排行或列表（“哪些商品”“有哪些”“哪几个”“前 N 个区域”）：即使最终只有一行，也按实体 → 当前时间 bucket → comparison metric 输出；这条覆盖“增长率最快的商品有哪些”这类 wording，不能因“最快”而退回单数 Top 1 projection；
- 无实体维度的整体 comparison（例如 `percentage growth in total sales volume from Q1 2022 to Q1 2023`）：当前时间 bucket → comparison metric；
- 英文 `from <previous period> to <current period>` / `in <current period>` 且还有实体维度时，可将当前时间 bucket 放在实体维度前，例如：month/quarter → region/province → comparison metric。

排名用的本期指标是 query helper；除非用户要求展示该本期值，必须从 compose 排除。基期值同理，只有 bare “及其同比/环比”或明确问“上期值/去年同期值”时才输出。即使用户只问“哪个/什么”，comparison metric 本身仍是请求输出，不要只返回实体名。

## 输出显示名

`previous` / `previous_growth` / `previous_growth_rate` 是派生公式，没有数据集字段或指标可以回填业务名；不提供显示名时，图例和表格列头显示的是 uid（例如 `yoy`、`mom`）。这类输出列必须用 `--expr-label UID=TEXT` 提供用户语言的可读名：

```bash
hbi data-model query --app <app> --dataset <dataset> \
  --expr sales="sum({销售额})" \
  --expr yoy="previous_growth_rate(sum({销售额}), 'year', 1, {日期})" \
  --expr mom="previous_growth_rate(sum({销售额}), 'month', 1, {日期})" \
  --expr-label yoy="销售额同比增长率" \
  --expr-label mom="销售额环比增长率" \
  --by month="month({日期})" --title "销售额月度同环比" --evidence --output json \
  | hbi chatbi compose --app <app> --dataset <dataset> \
      --select month --select yoy --select mom \
      --order month --order yoy --order mom --diagnostics --input - --output json
```

规则：

- 名称按实际比较口径写：同比/环比由 `period` 和 `offset` 共同决定，`'year', 1` 与 `'month', 12` 都是同比；不要把同一年、月口径混叫。
- 名称要包含基础指标和结果单位；同一张图里多个指标或多个比较口径不得同名（“销售额同比增长率”“销量同比增长率”）。
- 用户用英文或其它语言提问时，显示名使用同一种语言；不要用 uid 推导名称，也不要只写“增长率”“同比”这类缺少指标的词。
- `--expr-label` 只标注表达式输出轴（`--expr` 的 uid，或位置参数 HQL 的 `value`）；未知 uid 会在本地报错，维度轴不接受该参数。

## 输出列补充规则

- `previous` / `previous_growth` / `previous_growth_rate` 必须在 query 中保留本期时间 bucket 作为 comparison axis；
- period comparison 若展示本期指标与 comparison 输出，当前 time bucket 也应展示，顺序通常为实体 → 当前 time bucket → 本期指标 → comparison；若只展示 comparison 输出且用户按英文 `from/to/in <period>` 或“按月/季度”等期间提问，当前 time bucket 放在实体前；
- 用户只问增长率、增量或上期值时，本期聚合值只是 query helper，必须从 compose 排除。
