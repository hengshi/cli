## Interpret the current dashboard

当 runtime manifest 含 `selectedDashboard` 且用户要求解读当前仪表盘时，先读取服务端授权的有界结构摘要：

```bash
hbi chatbi dashboard-context --app <dashboard_app_id> --dashboard <dashboard_id> --output json
```

该摘要给出仪表盘标题、整体解读指导、图表 inventory（含每个图表的 `interpretation` 解读指导）与筛选器 inventory，但不复制完整布局或运行时 options。
根据 inventory 对每个与问题相关的持久化图表执行：

```bash
hbi element chart show <chart_id> --dashboard <dashboard_id> --app <dashboard_app_id> --output json
hbi element chart query <chart_id> --dashboard <dashboard_id> --app <dashboard_app_id> --output json
```

- `selectedDashboard` 是整盘读取的服务端权限边界；scope 里的 `applications` 是看板图表实际读取的数据包（服务端推导），可用于新的分析；clientContext 中的当前筛选值只是有界 view hint，不能扩大 app、dashboard 或 chart 范围。
- 整盘解读必须同时应用两级已保存指导：`dashboard.interpretation` 约束整盘分析思路，`charts[].interpretation` 约束对应图表的分析重点；二者都是指导，不是数据事实或权限依据。
- 优先覆盖仪表盘的核心指标、趋势、对比和异常；图表很多时按标题、类型和解读指导选择相关图表，避免无差别重复查询。
- 每个结论必须来自对应 chart query 的真实结果。不得读取 DOM，不得重新运行 compose 生成重复图表。
- 后续追问仍绑定同一 dashboard conversation；只有用户显式依赖之前回答时才按需读取 conversation-context。

## 超出已保存图表的分析

当问题需要看板没有预置的筛选或聚合时，用 `dashboard-context` 里任一相关图表的 `dataAppId` / `datasetId`
读取数据包上下文，再执行查询：

```bash
hbi chatbi context --app <dataAppId> --dataset <datasetId> --output json
hbi data-model query --app <dataAppId> --dataset <datasetId> ... --output json
```

- 数据范围由 scope 的 `applications` 决定（看板图表实际读取的数据包）；`applications` 之外的应用和数据集仍然拒绝。
- 看板当前的筛选值只是 view hint，不会自动套用到新查询；回答中要说明这一点。
- 严格权限检查、`POLICY_DENIED`、403 都是最终结果：如实说明，不重试，也不换命令或换数据集绕过。
- 已保存图表仍是“解读当前仪表盘”的首选证据；不要用新查询重建已有图表。
