---
name: hql-expert
description: "Hengshi Expression / HQL authority for HBI CLI. Use this skill whenever the user asks for `--expression` values, metric or measure formulas, dataset field expressions, `data-model query` HQL, `summarize_complete` / `select_fields_complete` / dataset-function HE, cross-dataset field references, or wants to translate business analysis language into executable HE/HQL. Also use it for advanced functions like `date_compare`, `previous`, `calculatex`, `lookupvalue`, `retention`, window functions, or when the task is formula authoring rather than raw SQL."
metadata:
  requires:
    files: ["references/"]
---

# HQL Expert

This skill exists to turn **business intent or CLI authoring tasks** into **correct Hengshi Expression / HQL**, not to dump syntax trivia.

Treat it as the authority for:

- formula authoring
- formula validation / rewrite
- HE JSON structure
- function-family selection
- metric / measure / dataset-column / data-model-query expression boundaries

## Read order

Read only what you need:

1. `references/terminology.md` for resource boundaries (`metric` vs `measure` vs `dataset` vs `data-model`)
2. `references/hql-specification.md` for syntax, AST, field references, clauses, and HE node shapes
3. `references/function_reference.md` for function routing, signatures, advanced families, dataset/table contracts, and support caveats

If references are still not enough, escalate in this order:

1. current CLI command behavior
2. frontend parser / type behavior
3. backend HQL / HE implementation
4. JARVIS HQL / chart-calculation / data-agent knowledge

## Work in lanes, not in one generic “formula mode”

Before writing anything, decide which lane the task belongs to:

| Lane | Typical ask | What to produce |
| --- | --- | --- |
| Metric | `metric create/update --expression`, `c1/c2` | one aggregate-oriented expression |
| Measure | `measure create/update --expression`, `m1/m2` | expression plus awareness of dimensions / where / timeDimension context |
| Dataset column | `dataset column-create/update --expression` | row-level or mixed expression suitable for a dataset field |
| Data-model query | `data-model query --app --dataset "<HQL>"` | analytic query expression and, when needed, grouped/filtered CLI command |
| Dataset/table HE | `summarize_complete`, `select_fields_complete`, pipeline/table authoring | HE JSON or contract explanation |
| Chart advanced calc | `date_compare`, `previous`, retention, moving/window calcs | function-family guidance with chart/runtime caveats |

Do not flatten these lanes into “all HQL is the same.” The syntax overlaps, but the **context contract does not**.

## Core workflow

### 1. Identify the execution context

Pin down all of these before authoring:

- which resource is being authored: metric, measure, dataset field, query, pipeline node, or chart calc
- dataset / app scope
- exact field names already available
- whether the user wants:
  - expression text
  - a ready-to-run CLI command
  - HE JSON / AST
  - explanation / validation only

If field names or dataset scope are missing, say so and ask for them or point to the relevant discovery command.

### 2. Choose the minimum sufficient output

Default outputs, in order:

1. **text HQL**
2. **quoted CLI command using that HQL**
3. **HE JSON / AST**, only when the caller explicitly wants structure or the contract is inherently HE-shaped

Do not default to JSON if plain text expression will do.

### 3. Map business intent to the right function family

Think in this order:

1. plain row logic (`case when`, `if`, string/time/math helpers)
2. aggregate (`sum`, `avg`, `count`, `distinct_count`, `percentile`, ...)
3. window (`rank`, `lag`, `lead`, `over(...)`)
4. advanced calculation (`date_compare`, `previous`, `date_accumulate`, `calculatex`, retention families)
5. cross-dataset / dataset-table HE (`dataset`, `lookupvalue`, `summarize_complete`, `select_fields_complete`)

If the request falls into 4 or 5, read `references/function_reference.md` before answering.

### 4. Respect current CLI / runtime contracts

Important repo-backed contracts:

- `metric create/update --expression` stores a formula-like expression for **atomic metrics**
- `measure create/update --expression` is not just “metric with another prefix”; measures carry **analysis context** like dimensions and filters
- `dataset expression-rewrite --app --dataset --expression` is the simplest dataset-scoped validation / rewrite path
- `data-model query` currently builds **analytic HE** around `summarize_complete(...)`, not raw SQL-style table projection
- pipeline/table authoring may emit `select_fields_complete(...)` and other dataset-function HE directly

## Lane-specific guidance

### Metric lane

Use when the user wants a reusable atomic metric on a dataset.

Bias toward:

- `sum(...)`
- `avg(...)`
- `count(...)`
- `distinct_count(...)`
- ratio formulas assembled from these

Return:

- expression first
- CLI command second if helpful

Remember:

- metric field names usually look like `c1`, `c2`
- do not confuse metric authoring with measure authoring
- `date_compare` / `previous` can appear in a metric formula, but that does **not** automatically bind `timeDimension` / `granularity` / measure-style context; the downstream query or chart still needs to provide the matching time axis
- if the user really wants a reusable same-period / previous-period analysis object with fixed dimensions, filters, or time semantics, steer toward `measure`, not a bare `metric`

### Measure lane

Use when the user wants a **business metric**, not just a field formula.

Remember:

- measure field names usually look like `m1`, `m2`
- a measure carries more analysis semantics than a metric
- if the user asks for a measure formula, think about whether dimensions / tags / description / time semantics also matter

Do not answer as if measure is only “same formula, different command.”

### Dataset column lane

Use when the user is authoring a dataset field expression.

Common fits:

- `case when`
- string/date normalization
- arithmetic combinations
- null handling with `coalesce` or Hengshi null-safe operators

Best companion command:

```bash
hbi dataset expression-rewrite --app <app-id> --dataset <dataset-id> --expression "<HQL>"
```

### Data-model query lane

Use when the user wants ad hoc analysis against a data model.

Remember:

- current CLI takes HQL as a positional value
- `--by` builds dimension expressions
- `--where` becomes filter conditions
- the CLI constructs `summarize_complete(...)` under the hood

So for query authoring, think “analytic result expression,” not “full SQL statement.”

### Dataset/table HE lane

Use when the user asks about:

- `dataset(...)`
- `select_fields(...)`
- `select_fields_complete(...)`
- `summarize(...)`
- `summarize_complete(...)`
- join-family dataset functions
- pipeline/table node HE

In this lane, structured HE may be the right output.

### Chart advanced calc lane

Use when the user asks for:

- same-period comparison / previous period
- cumulative / moving / retention / active / repetition
- post-aggregate calculations like `calculate`, `calculatep`, `calculatex`

Important nuance:

- these are HQL families, but chart authoring may still wrap them in **chart/runtime config**, not just raw formula text
- do not pretend a chart-side advanced calc is always solved by dropping a naked function call into a metric
- if the ask sounds like “make this reusable with built-in time semantics” rather than “write the function syntax”, prefer the **measure lane** (or explicit chart/query guidance) over a default `metric create`

## Output patterns

### If the user wants only an expression

Return:

```text
<expression>
```

Then optionally a one-line note about assumptions.

### If the user wants a runnable CLI command

Return:

```bash
hbi <resource> ... --expression "<expression>"
```

### If the user wants HE JSON

Give the smallest contract that matches the current lane. Prefer real field names and current repo-backed node shapes.

## Guardrails

- Never invent field names.
- Never output raw SQL when the task is HQL authoring.
- Never use the stale `data-model query --he ...` shape.
- Do not claim vendor-wide support for advanced functions unless source evidence says so.
- Do not infer advanced-function parameter lists only from backend placeholder signatures; many are internal/runtime-only and need public docs or stronger product context.
- If a request sounds like chart runtime configuration rather than pure formula design, say so and route accordingly.

## Practical discovery commands

Use or suggest these when context is missing:

```bash
hbi dataset fields --app <app-id> --dataset <dataset-id>
hbi dataset preview --app <app-id> <dataset-id>
hbi data-model show --app <app-id> --dataset <dataset-id>
hbi metric list --app <app-id> --dataset <dataset-id>
hbi measure list --app <app-id> --dataset <dataset-id>
hbi dataset expression-rewrite --app <app-id> --dataset <dataset-id> --expression "<HQL>"
```

## Cooperation with other skills

- Use `hbi-data` for dataset/model/resource discovery
- Use `hbi-data-modeling` when join structure or fact/dimension boundaries are unclear
- Use `hbi-dashboard` when the user is really asking about chart/filter/runtime authoring rather than pure HE/HQL
