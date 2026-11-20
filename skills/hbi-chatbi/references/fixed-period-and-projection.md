# Fixed period and projection

先判断日期的语义：如果用户只用日期限定一个报告期，而没有问“按月/每天/趋势/哪个期间”，日期是 filter，不是 chart 列。“过去 N 天/月/年”“近 N 期”“2023 年”“截至某日”都只是报告窗口；它们本身不构成时间序列。

固定期间 KPI 只投影请求指标：

```bash
hbi data-model query --app <app_id> --dataset <dataset_id> \
  --expr sales="sum({sales})" \
  --where "{date} >= '2023-09-01' AND {date} < '2023-10-01'" \
  --evidence --output json \
  | hbi chatbi compose --app <app_id> --dataset <dataset_id> \
      --select sales --order sales \
      --diagnostics --intent-value '{"requiredOutputs":["sales"]}' \
      --input - --output json
```

固定期间 Top N 或实体比较投影实体和请求指标；不要因 query 使用日期 filter 而选择日期列：

```bash
hbi data-model query --app <app_id> --dataset <dataset_id> \
  --expr sales="sum({sales})" \
  --by brand="group({brand})" \
  --where "{date} >= '2023-01-01' AND {date} < '2023-02-01'" \
  --sort sales:desc --sort brand:asc --limit 10 --evidence --output json \
  | hbi chatbi compose --app <app_id> --dataset <dataset_id> \
      --select brand --select sales \
      --order brand --order sales \
      --diagnostics --intent-value '{"requiredOutputs":["brand","sales"]}' \
      --input - --output json
```

只有以下情形才在固定期间 query 中选择时间：

- 用户明确要求显示日期、期间或按时间拆分；
- period comparison（此时读 `period-comparison.md`）；
- 时间序列、按时间展示的 share。

`--having` 中的阈值指标仍是用户请求的 output：“销量大于 X 的月份”至少选择 `month, sales`。但只问“某月销量是多少”时，不要为了 filter 或 helper 暴露额外的日期、当前值或基期值。

“哪些 / 有哪些 / 哪些店铺在哪些月份 / 每个”这类 threshold/list 没有数量上限时请求全部匹配项，不是 Top 10。最终 query 显式使用有界大 limit（例如 `--limit 1000`），并按请求实体维度、时间维度、阈值指标、目标/阈值指标的顺序投影。

先用 compose 列白名单表达展示契约：

- `--select` 只保留用户明确请求的维度和指标；
- `--order` 覆盖每个 selected uid，顺序按问题展示主语，不复制 query 的 `--by` 顺序；
- 排名或计算 helper 只有在用户要求展示时才进入 compose。
