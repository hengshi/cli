# 绑定与 HQL：命名 literal 与特殊口径

何时读：问题里出现具体的公司、组织、品牌、产品、地点、编号等取值（literal）、复合名称，或需要下列特殊口径时读本文件。字段绑定的通用规则、保存表达式和 HQL 写法已在 SKILL.md，不在这里重复。

依据 context 绑定指标、维度、时间和筛选。dataset scope 使用最小数量的 discovery、
`hbi data-model value-search` 或 query。规范路径仍是
`hbi data-model value-search`；`hbi chatbi value-search` 作为兼容别名可用，
参数、权限和输出契约完全相同，不要把它当成另一套 ChatBI 语义接口。普通模糊
value-search 通过受控 chart-data lexical query 执行，不依赖旧的 vector DB；exact
与 fuzzy 都受 delegated grant 和字段范围限制。
subject scope 不使用 value-search，也不调用 `/measures/query` 或 `kanbans/refine-chart`；需要发现成员值时，
使用一个带已绑定指标和必要 `--by` 的有界 `hbi chatbi query --subject ...`。Agent 不生成 raw chart options。

## 命名 literal 与特殊口径

- 最终 query 前先写出所有命名 literal checklist；每个公司、组织、品牌、产品、地点等 literal 都必须有绑定证据或明确进入 `--where`。即使 context root 未展示候选字段，也要对未绑定 literal 运行 `hbi data-model value-search --exact --query "<原始 literal>"`；不能只搜索其中一个 literal 后省略其他 literal。
- 单一命名实体默认是范围约束，必须进入 `--where`；只有用户要求按该实体拆分、排行或比较时才用 `--by`。不得把“蒙牛集团”“小小贝公司”这类限定对象自动变成 chart 输出列。
- 复合命名 literal 必须先整体执行 `hbi data-model value-search --exact --query "<原始 literal>"`。exact 未命中时，对同一个完整 literal 做一次普通 `hbi data-model value-search`。若二者均未给出 canonical binding，且 relation hint 存在语义匹配字段，可按 [semantics-and-binding.md](semantics-and-binding.md) 做一次有界 relation-candidate query；只有归一化后词干全等的唯一候选、且最终 query 验证成功时才可绑定。不得拆词做包含猜测或凭行业常识选择候选。
- 代码、编号类 literal（纯字母数字，或带 `.`/`-` 等分隔符）在 exact 未命中后，可用 `hbi data-model value-search --prefix --query "<literal>"` 做前缀匹配，覆盖 `600519` → `600519.SH` 这类变体；前缀结果不是唯一绑定，多个候选时澄清。
- value-search 输出带 `coverage` 与 `truncated`：`partial` 表示结果被 `--limit` 截断，`unmatchedQueries` 只说明“不在这一页”，不能据此回答“数据不存在”；应收窄关键词、提高 `--limit` 或让用户确认。
- 大数据集上先用 `hbi chatbi context` 的 `valueSearchCapability`/字段清单确定候选字段并传 `--candidate-field`，避免默认对几十个文本字段逐个扫描。
- 一旦命名 literal 找到 canonical binding，最终 query 必须显式保留该等值条件；不得因为能得到“看似合理”的结果而省略它。普通 fuzzy value-search 的未命中不能证明数据不存在。
- 不得擅自加 `COALESCE`、`IS NOT NULL`、空字符串排除或其他未请求的成员过滤；除非用户明确要求，这些会改变问题的记录集合。
- 文本“包含/模糊匹配”优先使用 `like({field}, '%literal%')`（或 `LIKE_ANY`）；不要用 `position(...) > 0` 代替过滤，除非先用具体查询验证当前数据模型与方言支持该函数。这样可以避免字符串函数在复合 `--where` 条件下产生空结果。
- “标准差”未说明样本口径时默认使用 `stddev_pop`，不要写 SQL 风格 `STDDEV`、`STDDEV_SAMP` 或在答案中自行计算。
- “异常波动 / abnormal fluctuation”未给阈值时，不要仅因此澄清；按用户要求的时间粒度计算请求指标的 `previous_growth_rate` 或 `previous_growth`，输出时间 bucket、请求实体维度和 fluctuation 指标。若只有一个期间导致 comparison 为 `null`，这仍是有效 evidence；不要把 query helper 指标暴露到 chart。
- “A 比 B 高/低/卖得好”必须在一条 query 内完成：只按请求的比较维度 `--by`，为 A、B 分别写条件聚合 `--expr`，用 `--having` 比较两个 uid，并投影比较维度和两个值。不得把 A、B 放进 `--by`，也不得把多行结果留给回答文本人工比较。
- 比较指标必须保留问题的业务含义：销量、订单数、GMV、销售额不是可互换的。若“卖得好/销售表现”未直说指标，但 context 给出已保存销售额或可由销量 × 售价唯一推导的销售额，比较该销售额；不得降级为计数或原始销量。
- field description 若明确“如果没有特别说明，时间过滤按本字段”或同义默认时间声明，该字段是强制时间口径：所有时间 filter 和 `--by` 都使用它，不要因 GMV、支付金额、订单数等指标名切换到其他事件时间，也不要 fan-out。没有默认声明且只剩一两个候选时才分别运行受限 query。详见 [semantics-and-binding.md](semantics-and-binding.md)。
