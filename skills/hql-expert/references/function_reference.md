# HQL Function Reference

> Use this file as a **quick reference first** and a **contract note second**.

## Quick routing

| If the user needs... | Start here | Notes |
| --- | --- | --- |
| 普通求和/平均/计数/统计 | [Aggregate cheat sheet](#aggregate-cheat-sheet) | metric / measure / grouped analysis |
| 排名、前后行、窗口分析 | [Window cheat sheet](#window-cheat-sheet) | `OVER (...)` family |
| 同比/环比/累计/跨数据集取值 | [Advanced cheat sheet](#advanced-calculation-cheat-sheet) | often runtime-sensitive |
| 数据集查询、投影、分组、分页 | [Dataset/table cheat sheet](#datasettable-cheat-sheet) | dataset-shaped HE, not scalar formulas |
| 行级清洗、条件分桶、空值处理 | [Scalar helper cheat sheet](#scalar-helper-cheat-sheet) | dataset-field authoring and ordinary expressions |

## Aggregate cheat sheet

| Function | Public syntax | Return | Best for |
| --- | --- | --- | --- |
| `SUM` | `SUM(expression)` | `NUMBER` | 求和 |
| `AVG` | `AVG(expression)` | `NUMBER` | 平均值 |
| `MAX` | `MAX(expression)` | `ANY` | 最大值 |
| `MIN` | `MIN(expression)` | `ANY` | 最小值 |
| `COUNT` | `COUNT(expression)` | `INTEGER` | 计数 |
| `DISTINCT_COUNT` | `DISTINCT_COUNT(expression)` | `INTEGER` | 去重计数 |
| `FIRST` | `FIRST(expression)` | `ANY` | 首条记录值 |
| `LAST` | `LAST(expression)` | `ANY` | 末条记录值 |
| `MEDIAN` | `MEDIAN(expression)` | `NUMBER` | 中位数 |
| `PERCENTILE` | `PERCENTILE(expr1, literal_percent)` | `NUMBER` | 百分位数 |
| `PERCENTILE_CONT` | `PERCENTILE_CONT(literal_percent) WITHIN GROUP (ORDER BY expr1 [DESC \| ASC])` | `NUMBER` | 连续百分位 |
| `MODE` | `MODE() WITHIN GROUP (ORDER BY expr1 [DESC])` | `ANY` | 众数 |
| `NTH` | `NTH(expr1, expr2)` | `ANY` | 第 n 个值 |
| `LIST_COLLECT` | `LIST_COLLECT(expression)` | `ARRAY` | 收集为数组 |
| `SET_COLLECT` | `SET_COLLECT(expression)` | `ARRAY` | 去重收集 |
| `MIN_BY` | `MIN_BY(expr1, expr2)` | `ANY` | 按比较值取最小 |
| `MAX_BY` | `MAX_BY(expr1, expr2)` | `ANY` | 按比较值取最大 |

### Aggregate notes

- `FILTER (WHERE ...)` 可附着在部分聚合表达式后面
- `WITHIN GROUP (ORDER BY ...)` 常见于 `PERCENTILE_CONT` / `MODE`
- 聚合函数跟上 `OVER (...)` 后会以窗口函数方式工作

## Window cheat sheet

| Function | Public syntax | Best for |
| --- | --- | --- |
| `ROW_NUMBER` | `ROW_NUMBER() OVER (...)` | 行号 |
| `RANK` | `RANK() OVER (...)` | 排名（跳号） |
| `DENSE_RANK` | `DENSE_RANK() OVER (...)` | 密集排名 |
| `LAG` | `LAG(ARG, I) OVER([PARTITION BY expr1] [ORDER BY expr2 [DESC]])` | 取前 N 行值 |
| `LEAD` | `LEAD(ARG, I) OVER([PARTITION BY expr1] [ORDER BY expr2 [DESC]])` | 取后 N 行值 |
| `FIRST_VALUE` | `FIRST_VALUE(expr) OVER (...)` | 窗口首值 |
| `LAST_VALUE` | `LAST_VALUE(expr) OVER (...)` | 窗口末值 |
| `NTH_VALUE` | `NTH_VALUE(expr, n) OVER (...)` | 窗口第 n 值 |

### Window definition skeleton

```text
FUNCTION(args) OVER (
  [PARTITION BY expr1, expr2, ...]
  [ORDER BY expr1 [ASC|DESC], ...]
  [ROWS|RANGE BETWEEN ...]
)
```

### Window notes

- `OVER (...)` 是窗口语义的关键切换点
- 如果公开文档没有说明某个窗口 helper 的最终语法，不要从内部实现反推

## Scalar helper cheat sheet

这些函数主要用于 dataset-field authoring、普通表达式拼装、条件分桶和清洗。这里优先提供**可扫的类别视图**，而不是把所有 helper 都展开成一整张长表。

### String helpers

| Function | Typical use |
| --- | --- |
| `CONCAT` | 字符串拼接 |
| `SUBSTRING` | 截取子串 |
| `LENGTH` | 字符串长度 |
| `TRIM` | 去空格 |
| `LOWER` / `UPPER` | 大小写转换 |
| `REPLACE` | 字符替换 |
| `POSITION` | 查找位置 |
| `TO_STRING` | 转字符串 |

### Logical / conditional helpers

| Function | Typical use |
| --- | --- |
| `IF` | 条件判断 |
| `CASE WHEN` | 多分支条件 |
| `COALESCE` | 取第一个非空值 |
| `ISNULL` / `ISNOTNULL` | 空值判断 |
| `BETWEEN` / `BETWEEN_IE` | 区间判断 |
| `IN` / `NOTIN` | 列表判断 |
| `LIKE` / `LIKE_ANY` | 模糊匹配 |

### Math helpers

| Function | Typical use |
| --- | --- |
| `ABS` | 绝对值 |
| `ROUND` | 四舍五入 |
| `CEIL` / `FLOOR` | 上下取整 |
| `POWER` | 幂运算 |
| `SQRT` | 平方根 |
| `MOD` | 取模 |
| `GROWTH_RATE` | 增长率 |
| `LEAST` / `GREATEST` | 最小/最大比较 |

### Type conversion helpers

| Function | Typical use |
| --- | --- |
| `TO_STRING` | 转字符串 |
| `TO_NUMBER` | 转数字 |
| `TO_DATE` | 转日期 |
| `TO_DATETIME` | 转日期时间 |
| `TO_TIMESTAMP` | 转时间戳 |
| `TO_INTEGER` | 转整数 |
| `TO_BOOL` | 转布尔 |

### Time helpers

| Function family | Typical use |
| --- | --- |
| `TRUNC_*` | 时间截断/分桶 |
| `EXTRACT_*` | 提取年月日等粒度 |
| `ADD_*` | 时间偏移 |
| `DIFF_IN_*` | 时间差 |
| `AGE_IN_*` | 自然时间差 |
| `TODAY` / `NOW` | 当前日期/时间 |
| `END_OF_*` | 周期结束时间 |

### Scalar notes

- 对 scalar helper，优先把它们当作“表达式积木”
- 如果某个 helper 的公开参数合同不在当前文档/上下文里，就不要伪造一版详细签名
- Hengshi 还有 null-safe arithmetic：

```text
{a} +? {b}
{a} -? {b}
```

## Advanced calculation cheat sheet

这些函数最容易“看起来像普通公式，实际上受 runtime / chart / query context 约束”。

| Function family | Public syntax / contract | Best for | Important note |
| --- | --- | --- | --- |
| `DATE_ACCUMULATE` | `DATE_ACCUMULATE(function1(function2(expression)), date_expression, reset_period)` | 累计 | 需要基础聚合 + 时间维度 + reset period |
| `DATE_COMPARE` | `DATE_COMPARE(function(expression), date_expression1, date_expression2)` | 日期对比 | 常用于对比另一个时间表达式 |
| `PREVIOUS` | `PREVIOUS(function(expression), period, delta)` | 上期/同比/环比 | `period` / `delta` 可选，常依赖图表时间轴 |
| `LOOKUPVALUE` | `LOOKUPVALUE(ARG1, ARG2, ARG3)` | 跨数据集取值 | `ARG1/ARG2` 常带 dataset id，`ARG3` 要和当前维度对上 |
| `CUSTOM_FILTERS` | `CUSTOM_FILTERS(expression, [{field1},{field2}], condition)` | 自定义筛选器 | runtime 语义较强 |
| `CALCULATEX` | first arg = precomputed expression; remaining args = one or more grouping expressions | 聚合后再算 | 常用于图表过滤或新增指标 |
| `TOP_N` / `BOTTOM_N` | ranking-style post-aggregate helpers | Top/Bottom 排名 | 通常属于 rewrite-style family |
| `ROLLUP_VALUE` | partial rollup helper | 部分维度聚合 | 常带 runtime context |

### Retention / active / repetition families

常见函数名：

- `retention`
- `continuous_retention`
- `static_retention`
- `static_retention_rate`
- `static_continuous_retention`
- `static_continuous_retention_rate`
- `repetition`
- `repetition_count`

Use these for:

- 留存
- 连续留存
- 活跃 / 回访
- repeated occurrence analysis

Important note:

- 这些是**产品语义函数**
- 如果手头没有公开参数合同，不要从 backend placeholder 反推裸语法

## Dataset/table cheat sheet

这些函数返回的是 dataset-shaped result，不是普通 scalar expression。

| Function | Public syntax / contract | Best for |
| --- | --- | --- |
| `DB_SOURCE` | `DB_SOURCE(connectionId, path, tableName)` | 从连接层取源表 |
| `DATASET` | `DATASET(id)` | 当前应用语境下取数据集 |
| `APP_DATASET` | `APP_DATASET(appId, datasetId)` | 跨应用取数据集 |
| `FILTER` | `FILTER(dataset_expression, filter_expression)` | 过滤 dataset |
| `SELECT_FIELDS` | first arg = dataset expression; remaining args = one or more field expressions | 投影 |
| `SUMMARIZE` | first arg = dataset expression; remaining args = one or more expressions that group/aggregate together | 分组汇总 |
| `SELECT_FIELDS_COMPLETE` | dataset expression + field array + filter array + sort array + offset + limit | 投影 + 过滤/排序/分页 |
| `SUMMARIZE_COMPLETE` | dataset expression + expr array + filter array + having array + sort array + offset + limit | 分组汇总 + 过滤/排序/分页 |

### Stable mental model

| Function | Think of it as |
| --- | --- |
| `dataset` / `app_dataset` | dataset root |
| `filter` | row filtering on a dataset expression |
| `select_fields` | projection |
| `summarize` | grouped summarization |
| `*_complete` | richer query contract with filters, sort, paging |

## Current CLI-backed contracts

### `data-model query` → `summarize_complete`

Current CLI behavior maps to:

| Arg | Meaning |
| --- | --- |
| `arg0` | dataset expression |
| `arg1` | expression list = `--by` dimensions + main metric expression |
| `arg2` | where filters or `null` |
| `arg3` | having or `null` |
| `arg4` | sort or `null` |
| `arg5` | offset |
| `arg6` | limit |

This is the key contract behind current `hbi data-model query`.

### `pipeline` SELECT node → `select_fields_complete`

Current pipeline SELECT-node behavior uses:

- dataset reference
- field list
- filter list / sort / paging when the command surface provides them

Treat it as table/pipeline projection, not scalar metric authoring.

## Alias snapshot

Prefer canonical names unless there is a strong reason to preserve an alias.

| Alias | Canonical |
| --- | --- |
| `uppercase` | `upper` |
| `lowercase` | `lower` |
| `ifelse` | `if` |
| `year` | `trunc_year` |
| `month` | `trunc_month` |
| `day` | `trunc_day` |
| `yearadd` | `add_year` |
| `dayadd` | `add_day` |
| `pth` | `percentile` |

## Safety notes

1. Date/time functions are the biggest cross-vendor risk zone.
2. Window and advanced-calculation behavior is not perfectly uniform across data sources.
3. Many advanced functions have internal/runtime-only forms in backend definitions; do not hallucinate public argument layouts.
4. Chart-side advanced calculation may require chart/runtime config in addition to raw HQL.
5. Dataset/table functions are HE/query contracts, not just pretty formula text.

## Practical answer rules

1. First classify the ask into scalar / aggregate / window / advanced / dataset-table.
2. For plain authoring, prefer the cheat-sheet tables.
3. For advanced or dataset-table questions, read the contract notes below the tables.
4. If a syntax is variadic, describe argument roles instead of hiding behind an unexplained `...`.
5. If the user asks for data-source support, do not guess.
