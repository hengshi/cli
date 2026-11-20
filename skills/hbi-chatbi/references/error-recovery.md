# 错误恢复与收尾

## 通用原则

- 同一条失败命令不要原样重试。同一个问题上最多尝试两种不同形状；仍失败就缩小范围或返回最小澄清。
- 失败后不得静默更换应用或数据集；需要换 scope 时按 [scope-and-context.md](scope-and-context.md) 的澄清规则处理。
- 先读 CLI 的真实错误文本（`error.message`、`error.errorCode`、`exitCode`），不要根据现象猜原因。
- 内部错误只在 loop 内修复，不作为最终回答内容；最终回答只描述业务结论和必要的失败语义。

## HQL / having 失败

- `--having` 可以直接引用 `--expr` 和 `--by` 的 uid，CLI 会在发送前展开：`--expr` uid → 保存表达式，`--by` uid → 维度表达式。
- 多个 `--having` 是 AND；需要 OR 时重复 `--having-any`（组内 OR），两组之间是 AND。例如 `--having "c > 0" --having-any "a > 0" --having-any "b > 0"` 表示 `c > 0 AND (a > 0 OR b > 0)`。flat OR 一律用 `--having-any`，不要写成单条字符串；只有 `--having-any` 表达不了的嵌套混合布尔（例如 `(a > 0 OR b > 0) AND (c > 0 OR d > 0)`）才写成单条 `--having`。
- 本地会拒绝的情况：无法识别的标记（拼写错误、未加引号的字符串）或无法解析的语法。按错误文本修正，不要原样重试。
- 如果仍出现 `HBI_COMMAND_FAILED` / `error/hql-cast-fail`：通常是常量类型不一致（数字别名与字符串比较），改成匹配的类型；仍失败再去掉 `--having`，按相关指标排序取有界 Top N，并在回答里说明筛选口径。
- 保持 HQL 语法：字符串用单引号、列表用 `in ['A', 'B']`、uid 用短 ASCII 标识符；不要直接搬 SQL 写法。

## compose / answerability

- `ready=false`：按 `nextActions` 修正 projection 或补齐 evidence；不要用缺失的必需输出作结论。修正后最多重跑一次。
- `ready=true` 但没有 `luiChart`：问题适合可视化且诊断给出具体原因时，做一次针对性修正；否则按文本回答并完成本轮，不要伪称已生成图表。
- 同一个 compose 不要原样重复。runtime-managed receipt 会累积本轮图表（最多 8 张），最后一次 `ready=true` 的 stdout 已包含全部图表。
- 如果图表无法生成但 query evidence 已足够，直接输出文本答案；单一汇总指标仍应尝试 KPI 图。

## 时间与轮次预算

- 目标是尽快给出终态。图表全部 `ready` 后不要再做数据范围核对、重复 query、格式检查或额外的整盘扫描。
- 复杂多目标问题：先用一条 query 覆盖多个指标，再按需要拆成最多 8 张图 compose；不要把每个指标拆成独立 query。
- 已经积累较多工具调用时，优先输出已有证据支持的结论；不要在最后阶段继续扩展分析。
- 最后一次 compose 成功后立即停止所有 HBI 调用并输出最终 JSON。不要在同一轮里为了“再确认一下”重跑已完成的 query。
