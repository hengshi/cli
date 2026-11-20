# Share and partition-share

先判断分子与分母是否位于最终 `--by` 的同一粒度。

同粒度占比使用一条条件聚合 evidence query。公共时间、地点和实体筛选放入 `--where`；只有分子独有成员条件留在 `IF(...)` 内。最终只输出 ratio，不能输出分子、分母或在文本中相除。

```bash
hbi data-model query --app <app_id> --dataset <dataset_id> \
  --expr high_end_share="SUM(IF({hotel_type} = '高档型', 1, 0)) / COUNT({order_id})" \
  --expr-label high_end_share="高档型订单占比" \
  --where "{city} = '上海市'" --evidence --output json \
  | hbi chatbi compose --app <app_id> --dataset <dataset_id> \
      --select high_end_share --order high_end_share \
      --diagnostics --intent-value '{"requiredOutputs":["high_end_share"]}' \
      --input - --output json
```

订单去重时使用 HQL `distinct_count(...)`，不要写 SQL `COUNT(DISTINCT ...)`。

跨粒度占比（例如按商圈、品牌展示，但分母只按商圈）使用 `partition-share`。两条 evidence query 必须有相同的 `--where` 和 `--having`、相同单一 metric、无排序，且真实行数小于 `--limit`；否则不能计算。

所有分母 `--by` uid 都是分区键，必须逐个传给 `partition-share --partition-key`。例如分子按 `month,district,brand`、分母按 `month,district` 时，必须传 `--partition-key month --partition-key district`，不能只传其中一个。

不要只在分子 `--where` 添加品牌/成员条件而分母不加：这会违反相同 filters 契约。若给分子与分母同时加该条件，分母的业务含义也会变成“所选成员总额”，不再是全体份额；先确认这是否仍符合用户问题。`partition-share` 失败时不得退化成把每个成员变成独立条件聚合列；用户要求逐成员行时，最终 evidence 必须保留贡献维度并以 `partition-share | compose` 结束。

```bash
hbi data-model query --app <app_id> --dataset <dataset_id> \
  --expr order_count="COUNT({order_id})" \
  --by district="group({district})" --by brand="group({brand})" \
  --where "<same filters>" --limit 100 --evidence --output json \
  --write-output /tmp/chatbi-numerator.json

hbi data-model query --app <app_id> --dataset <dataset_id> \
  --expr order_count="COUNT({order_id})" \
  --by district="group({district})" \
  --where "<same filters>" --limit 100 --evidence --output json \
  --write-output /tmp/chatbi-denominator.json

hbi chatbi partition-share --app <app_id> --dataset <dataset_id> \
  --numerator /tmp/chatbi-numerator.json \
  --denominator /tmp/chatbi-denominator.json \
  --partition-key district \
  --numerator-value order_count --denominator-value order_count \
  --output-value order_share --output json \
  | hbi chatbi compose --app <app_id> --dataset <dataset_id> \
      --select district --select brand --select order_share \
      --order district --order brand --order order_share \
      --diagnostics --intent-value '{"requiredOutputs":["district","brand","order_share"]}' \
      --input - --output json
```

Numerator must contain the partition key plus a contribution dimension; denominator must group by exactly that key. Do not edit the evidence files. Only the two job-local `/tmp` evidence files are permitted writes.

当问题的展示主语是“每个月 / 按月的市场份额”，time bucket 是第一列。分子按 `month,province,brand`、分母按 `month,province` 时，终态必须为：

```bash
hbi chatbi partition-share ... --partition-key month --partition-key province \
  | hbi chatbi compose --app <app_id> --dataset <dataset_id> \
      --select month --select province --select brand --select share \
      --order month --order province --order brand --order share \
      --diagnostics --intent-value '{"requiredOutputs":["month","province","brand","share"]}' \
      --input - --output json
```
