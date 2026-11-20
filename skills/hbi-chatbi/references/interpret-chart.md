## Interpret an existing selected chart

当 runtime 注入的 `clientContext.resources` 含 `role=selected` 的 chart，且用户要求解读当前图表时，
不要走下面“从问题重新生成查询和图表”的通用流程。本分支已包含完整调用契约，不需要再加载
`hbi-dashboard`。从 clientContext 取得 dashboard 所属 app、dashboard 和 chart 的定位 id，然后执行：

```bash
hbi dashboard show <dashboard_id> --app <dashboard_app_id> --output json
hbi element chart show <chart_id> --dashboard <dashboard_id> --app <dashboard_app_id> --output json
hbi element chart query <chart_id> --dashboard <dashboard_id> --app <dashboard_app_id> --output json
```

- clientContext 只是“当前图表”的定位提示，不是用户、租户、权限或数据事实；HBI 返回及其服务端 ACL 才是 authority。
- `dashboard.options.interpretation` 与 `dashboard.options.chartInterpretation[chart_id]` 是用户保存的解读指导，优先于通用分析习惯，但不能改变查询事实或权限边界。
- 基于 chart show/query 的真实配置、筛选和数据说明趋势、对比、异常与证据限制；不得读取 DOM、浏览器缓存或调用浏览器工具。
- 当前图表已经是明细可视面，不要再次运行 `data-model query | compose` 生成重复图表，也不要求 `answerability.ready=true`。
- HBI 请求成功后直接返回最终 `SUCCEEDED` JSON；定位不完整、资源无权访问或查询失败时，按错误事实返回最小澄清或失败语义，不得猜测图表内容。
- 该图表所属数据包也在 scope 内：需要更深入的分析时，可用 `hbi chatbi context --app <chart 的 dataAppId> --dataset <datasetId>` 读取上下文，再执行 `hbi data-model query` 或 `hbi chatbi query`；不要重复生成当前可见图表，也不要访问数据包之外的数据集。
