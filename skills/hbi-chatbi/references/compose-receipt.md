# Compose receipt 与多图累积

主流程只需遵守 SKILL.md：不拼接 stdout，不手工操作 receipt；这里是机制细节。

ChatBI runtime 会在 `hbi chatbi compose` 成功收到 API 响应后，将组成结果合并写入 runtime
管理的 `/home/agent/workspace/.chatbi-compose-receipt.json`，再输出 stdout。同一个 agent job 中的
多次 compose 会按图表累积到同一份 receipt：`views`、`charts`、`chartsData`、`dataInfo` 逐图追加，
相同图表请求（标题、轴、filter、排序一致）会原位替换而不重复，最多保留最近 8 张图。每次 compose
的 stdout 都是合并后的完整组成结果，因此最后一次 compose 的输出已包含本轮全部图表；不要自己拼接
stdout 或 receipt。runtime 会在本轮 workspace archive 前读取并删除该 receipt，因此它不会进入下一轮
workspace，也不能作为跨轮文件依赖。stdout 可以按需 pipe 给 `jq`、`head`、`cut` 或其他命令做展示和
诊断；图表恢复以 runtime-managed receipt 为准。不要手工创建、修改或删除这个文件，也不要用它替代
HBI query/compose。
