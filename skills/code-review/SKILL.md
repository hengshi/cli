---
name: code-review
description: "Repo-local code review skill for everest-cli merge requests. Use when Copilot is asked to review an MR/diff in this repo and must produce actionable findings plus webhook-intake review artifacts."
---

# everest-cli code review

先按 diff 需要读取相关 repo-managed skills / docs。重点记住：

- `skills/` 是 repo-managed single source of truth。
- 改 CLI surface / request payload / lifecycle / runtime behavior 的变更，不能只停在 unit tests；要检查是否补了 targeted E2E 或 dry-run contract coverage。
- 如果 diff 触及 `skills/` 或 skill validator，检查 repo-native 的 skills validation 闭环是否被考虑。

## Review focus

只报真正影响正确性、兼容性、用户可预期性的点。优先看：

1. CLI 命令面（参数、默认值、help 文案、输出格式、资源生命周期）有没有无意 drift。
2. API path / payload / auth precedence / host/config resolution 是否与现有 contract 一致。
3. `skills/` 变更有没有破坏 skill contract、eval/validator 预期、或让 repo-managed source-of-truth 漂移。
4. 行为变更是否补了对应的 unit / E2E / dry-run contract 覆盖；如果没有，要指出风险。
5. 输入校验、错误处理、输出稳定性有没有倒退。

## Output contract

如果当前 review 是被 webhook-intake 触发，必须把结果写到 run 目录：

- `comment.md`
- `review-summary.json`
- `comment-action.txt`

run 目录优先取：

1. `REVIEW_RUN_DIR`
2. `INTAKE_RUN_DIR`

要求：

- `comment.md` 必须是干净 Markdown，不要带工具包装输出。
- `comment.md` 必须包含环境里给的 marker（优先 `REVIEW_BOT_MARKER`，否则 `INTAKE_BOT_MARKER`）。
- `review-summary.json` 必须包含：
  - `status`: `reviewed` 或 `blocked`
  - `reviewed_commit_sha`
  - `summary`
  - `blocking_issues`
  - `non_blocking_issues`
  - `generated_at`
- `comment-action.txt` 使用 `prepared-comment` 或 `blocked-comment`。

## Comment style

- 没有 actionable issue：明确写“本次未发现需要作者处理的问题”。
- 有问题：每条问题都说明 **用户面影响 / contract 风险 / 建议修正方向**，并尽量给到文件与行号。
- 如果证据不足，写 `blocked-comment`，说明缺失的 command/API/test evidence。
