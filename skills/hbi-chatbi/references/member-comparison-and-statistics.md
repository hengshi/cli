# Named-member comparison and dispersion

“A 比 B 高/低/卖得好”的 A、B 是条件，不是结果维度。先分别完整绑定两个 literal；最终用一条 query 计算比较，不要按成员分组后在回答文本中人工比较。

比较 query 必须：

1. 只按用户请求的比较维度分组；
2. 保留用户要求或 context 唯一推导出的业务指标；“卖得好/销售表现”在存在销售额或销量 × 售价候选时比较销售额，不能降级为销量或计数；
3. 为每个成员使用条件聚合；
4. 用 `--having` 保留满足比较关系的分组；
5. 将比较维度和两个比较值都投影给 compose，作为结论的可见证据。

```bash
hbi data-model query --app <app_id> --dataset <dataset_id> \
  --expr a_sales="sum({销量} * {售价}) filter(where {品牌} = '优乐美')" \
  --expr b_sales="sum({销量} * {售价}) filter(where {品牌} = '香飘飘')" \
  --expr-label a_sales="优乐美销售额" \
  --expr-label b_sales="香飘飘销售额" \
  --by province="group({省份})" \
  --where "{日期} >= '2023-01-01' AND {日期} < '2024-01-01' AND {类目} = '奶茶' AND {品牌} IN ['优乐美', '香飘飘']" \
  --having "{a_sales} > {b_sales}" \
  --sort province:asc --limit 1000 --evidence --output json \
  | hbi chatbi compose --app <app_id> --dataset <dataset_id> \
      --select province --select a_sales --select b_sales \
      --order province --order a_sales --order b_sales \
      --diagnostics --intent-value '{"requiredOutputs":["province","a_sales","b_sales"]}' \
      --input - --output json
```

不要把品牌放入 `--by`，不要通过两条 query 或多个成员行在答案中判断大小，也不要为了简化 chart 省略两个比较值。

“标准差”默认总体标准差：使用 `stddev_pop(<行级数值表达式>)`。逐月/逐日问题按请求时间粒度 `--by`，并输出时间和标准差；不要写 `STDDEV` 或 `STDDEV_SAMP`。用户明确要求样本标准差时，先从 context 的 function catalog 确认该函数受支持；不能静默把 sample 口径改成其他统计量。
