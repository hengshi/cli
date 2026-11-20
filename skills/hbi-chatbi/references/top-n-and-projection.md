# Top N and projection

Top N needs explicit ordering:

```bash
hbi data-model query --app <app_id> --dataset <dataset_id> \
  --expr order_count="COUNT({order_id})" \
  --by hotel="group({hotel_name})" \
  --sort order_count:desc --sort hotel:asc --limit 10 \
  --evidence --output json \
  | hbi chatbi compose --app <app_id> --dataset <dataset_id> \
      --select hotel --select order_count \
      --order hotel --order order_count \
      --diagnostics --intent-value '{"requiredOutputs":["hotel","order_count"]}' \
      --input - --output json
```

`--limit N` without `--sort` only truncates. Do not expose technical IDs. If the user requests business attributes plus a ranking metric, put requested attributes first and the ranking metric last. When there are additional requested metrics that are not the ranking metric, project them before the ranking metric. For example, “订单数最高的酒店，列出城市、商圈、GMV” orders columns as hotel → city → business district → GMV → order_count. Use `--select` as a whitelist and `--order` to cover every selected uid; repeat each flag rather than comma-joining values. For a threshold list, the threshold metric remains a requested output: “销量大于 1,800,000 的月份” projects both `month` and `sales`, not only `month`.

“哪个 … 最高 / 最低 / 最快 / 最慢”是单数 Top 1，不是普通列表：`--sort <metric_uid>:desc|asc --limit 1`。即使答案还要显示当前值和比较值，limit 仍然是 1。

“全部 / 每个 / 列出所有 / 哪些 / 有哪些” is not Top N. They request every matching item unless the user gives a number, page, or other bound. For a final ChatBI threshold/list query with no count, use `--limit 1000`, not the default 10; then read `total` / `hasMore` / `truncated` or equivalent result metadata and continue paging or state the returned scope if necessary. Do not use unbounded `--all`.
