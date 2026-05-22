# HQL / HE Specification Reference

> Use this file for syntax, AST shape, clause support, and operator rules.

## Core model

- **HQL** = Hengshi Query Language, the user-facing expression language
- **HE** = Hengshi Expression, the JSON/AST form used across frontend/backend
- CLI scenarios should prefer **text HQL**, not HE JSON, unless the caller explicitly asks for AST

## Common HE fields

The common HE node fields include:

| Field | Meaning |
| --- | --- |
| `kind` | Node kind such as `field`, `function`, `constant`, `formula`, `casewhen`, `param`, `attr`, `dataset`, `array` |
| `op` | Operator / function name / field name / literal payload, depending on `kind` |
| `args` | Function args or nested expression list |
| `dataset` | Dataset binding for cross-dataset field references |
| `type` | Output type |
| `value` | Constant / evaluated value |
| `window` | `OVER (...)` definition |
| `filter` | `FILTER (WHERE ...)` clause |
| `within` | `WITHIN GROUP (ORDER BY ...)` clause |
| `direction` | Sort direction on order items |
| `uid` | Node uid when needed by runtime/editor |
| `context` | Advanced context clause used by some rewrite functions |

Important note from backend: some HE fields are **internal-only** and not meant as user-facing syntax.

## Text syntax: high-value patterns

### Field references

```text
{amount}
{{2}}.{amount}
{{{17}}}.{{2}}.{amount}
{%start_date}
{$region}
```

| Syntax | Meaning |
| --- | --- |
| `{field}` | Current dataset field |
| `{{datasetId}}.{field}` | Cross-dataset field |
| `{{{appId}}}.{{datasetId}}.{field}` | Cross-app field |
| `{%param}` | Parameter reference |
| `{$attr}` | Attribute reference |
| `{{datasetId}}` | Dataset reference node |

### Constants

```text
42
3.14
'hello'
"world"
true
false
null
[1, 2, 3]
```

### Function calls

```text
sum({amount})
lookupvalue(...)
$.my_udf({field})
```

- `$.function_name(...)` is the UDF-style call shape
- Function args can nest arbitrary expressions

### Case expression

```text
case
  when {amount} > 1000 then 'high'
  when {amount} > 100 then 'mid'
  else 'low'
end
```

Backend AST kind is `casewhen`.

### Clauses

```text
avg({sales}) over(partition by {region} order by {created_at} desc)
sum({sales}) filter(where {status} = 'active')
percentile(0.5, {value}) within group(order by {value})
```

Supported clause families from backend/frontend parsing:

- `OVER (...)`
- `FILTER (WHERE ...)`
- `WITHIN GROUP (ORDER BY ...)`
- `AS alias`
- `CONTEXT (...)` for advanced rewrite/context-aware scenarios

## Operators

Backend parser recognizes these important operators:

- arithmetic: `+`, `-`, `*`, `/`, `%`, `^`
- comparison: `=`, `!=`, `<>`, `>`, `>=`, `<`, `<=`
- logical: `and`, `or`, `not`
- membership: `in`, `not in`
- special Hengshi operators: `+?`, `-?`

### Non-null operators

```text
{revenue} +? {refund}
{revenue} -? {refund}
```

`+?` / `-?` are Hengshi-specific null-safe add/subtract operators. They are not generic SQL syntax.

## Operator precedence

Distilled from JARVIS HQL module / parser behavior:

1. `or`
2. `and`
3. `not`
4. `not in`
5. `in`
6. `^`, `%`
7. `*`, `/`
8. `+`, `-`, `+?`, `-?`
9. comparisons: `>=`, `<=`, `=`, `!=`, `<>`, `>`, `<`

Do not assume SQL precedence blindly when explaining HQL; prefer parentheses in user-facing output when there is any ambiguity.

## Window clause shape

Supported backend pieces include:

- `PARTITION BY`
- `ORDER BY`
- `NULLS FIRST` / `NULLS LAST`
- `ROWS BETWEEN ... AND ...`
- bounds such as `UNBOUNDED PRECEDING`, `CURRENT ROW`, `N PRECEDING`, `N FOLLOWING`

Example:

```text
row_number() over(
  partition by {region}
  order by {created_at} desc nulls last
  rows between 1 preceding and 1 following
)
```

## HE JSON examples

### Field

```json
{
  "kind": "field",
  "op": "amount"
}
```

### Cross-dataset field

```json
{
  "kind": "field",
  "op": "amount",
  "dataset": 2
}
```

### Function

```json
{
  "kind": "function",
  "op": "sum",
  "args": [
    {
      "kind": "field",
      "op": "amount"
    }
  ]
}
```

### Formula wrapper

```json
{
  "kind": "formula",
  "op": "sum({amount})"
}
```

### Filtered aggregate

```json
{
  "kind": "function",
  "op": "sum",
  "args": [
    { "kind": "field", "op": "sales", "dataset": 2 }
  ],
  "filter": [
    { "kind": "formula", "op": "{region} = '北京'" }
  ]
}
```

### Window aggregate

```json
{
  "kind": "function",
  "op": "avg",
  "args": [
    { "kind": "field", "op": "sales", "dataset": 2 }
  ],
  "window": {
    "partition": [
      { "kind": "field", "op": "location", "dataset": 2 }
    ],
    "order": [
      { "kind": "field", "op": "date", "direction": "desc" }
    ]
  }
}
```

## Common dataset/table HE contracts

These are not just scalar formulas; they are dataset-shaped HE nodes.

### Dataset root

```json
{
  "kind": "function",
  "op": "dataset",
  "args": [
    { "kind": "constant", "op": 456 }
  ]
}
```

### `summarize_complete(...)`

Current CLI-backed analytic query shape:

```json
{
  "kind": "function",
  "op": "summarize_complete",
  "args": [
    { "kind": "function", "op": "dataset", "args": [{ "kind": "constant", "op": 456 }] },
    [
      { "kind": "formula", "op": "{{456}}.{region}", "uid": "region" },
      { "kind": "formula", "op": "sum({{456}}.{amount})", "uid": "value" }
    ],
    [
      { "kind": "formula", "op": "{{456}}.{status} = 'completed'" }
    ],
    null,
    null,
    0,
    10
  ]
}
```

Mental model:

| Arg | Meaning |
| --- | --- |
| `arg0` | dataset expression |
| `arg1` | dimension + metric expression list |
| `arg2` | where filters or `null` |
| `arg3` | having or `null` |
| `arg4` | sort or `null` |
| `arg5` | offset |
| `arg6` | limit |

### `select_fields_complete(...)`

Current pipeline SELECT-node usage:

```json
{
  "kind": "function",
  "op": "select_fields_complete",
  "args": [
    { "kind": "reference", "uid": "upstream" },
    [
      { "kind": "field", "op": "region" },
      { "kind": "field", "op": "amount" }
    ],
    []
  ]
}
```

Use this contract when the task is projection/table-node authoring rather than metric/measure formula authoring.

## Current CLI-relevant entry points

These are the highest-signal expression entry points in this repo:

```bash
hbi metric create --expression "sum({amount})"
hbi metric update --expression "count({order_id})"
hbi measure create --expression "sum({amount})"
hbi measure update --expression "avg({price})"
hbi data-model query --app <app> --dataset <dataset> "sum({amount})"
hbi dataset expression-rewrite --app <app> --dataset <dataset> --expression "sum({amount})"
hbi dataset column-create --expression "case when {amount} > 1000 then 'high' else 'low' end"
```

## Practical rules for agent answers

1. Default to text HQL.
2. Use exact field names only.
3. Prefer the smallest valid expression, not a whole SQL statement.
4. When explaining advanced syntax, distinguish clearly between:
   - pure expression syntax
   - backend/internal HE fields
   - data-source-specific SQL translation behavior
5. When unsure whether a feature is parser-level, function-level, or vendor-level, say so explicitly instead of flattening them into one “supported” claim.
