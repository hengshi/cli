# Dashboard Terminology Map

在以下场景继续读取本参考：

- 用户用自然语言描述需求，而不是直接说 `Line`、`Geo`、`CrossTable`、`filterTree`
- 需要把中文业务说法翻成 CLI / dashboard plan 术语
- 需要判断用户说的是“图表类型”“过滤器样式”还是“运行时行为”
- 需要 exact frontend canonical 名称或别名时，不要停在本文件，继续读取 `canonical-terms.md`

## 使用原则

- 这份文档重点是**意图映射**，不是完整术语总表；需要 exact canonical 术语时看 `canonical-terms.md`
- 先理解用户想表达的**展示意图**，再映射到内部术语；不要把内部术语原样反问给用户
- 用户说法通常比 CLI / plan 术语更宽泛，所以映射后还要补前置检查
- 如果一个自然语言说法可能落到多个 chartType / filter 配置，优先给最保守、安全的那个

## 图表术语映射

| 用户说法 | 推荐内部术语 | 何时优先这样映射 | 还要确认什么 |
| --- | --- | --- | --- |
| 趋势图 / 走势 / 按时间看变化 | `Line` | 有时间字段 + 指标 | 是否真有 timestamp 字段 |
| 面积趋势图 | `Area` | 想强调趋势面积感 | 是否真有 timestamp 字段 |
| 柱状图 / 条形图 / 排名对比 | `Bar` | 维度 + 指标对比 | 是否需要堆叠/分组 |
| 饼图 / 占比 / 构成 | `Pie` | 看份额构成 | 是否只需要单指标 |
| 环形图 | `Donut` | 饼图但想留中心空白 | 是否还需要中心文案 |
| 明细表 / 列表 / 原始记录表 | `DatasetTable` | 更像原始记录明细，不强调汇总 | 是否真的只是明细列表 |
| 交叉表 / 透视表 / 带小计的表 / 汇总表 | `CrossTable` 或 table family | 需要行列分组、小计、汇总、展开收起 | 是否需要 rollup / nesting / 列样式 |
| 指标卡 / 大数字 | `KPI` | 单个核心指标 | 是否还需要趋势 |
| 带趋势的指标卡 / 同比环比卡 | `KPITrend` | 大数字 + 趋势 | 趋势字段是否存在 |
| 地图 / 区域分布 / 省份地图 / 行政区地图 | `Geo2D` | 更像简易地图，按行政区或区域边界渲染 | 字段是否已有 geo role |
| 分层地图 / 多图层地图 / 经纬度地图 / 点位地图 / 连线地图 | `Geo` | 更像 deck.gl 分层地图，支持 `mapLayers` 和图层叠加 | 是否真有经纬度 / GeoJSON / 图层需求 |
| 点击下钻 / 点一下看下一层 | `zoomPath` | 点击后切到子图表 | 这不是 table 自带 rollup |
| 表格下钻 / 小计 / 汇总 / 展开收起 | table family + `drillDown` / nested axes | 表格内部层级聚合 | 这不是 `zoomPath` |

## 过滤器术语映射

| 用户说法 | 推荐内部术语 | 备注 |
| --- | --- | --- |
| 单选筛选 / 下拉单选 | `filterType: filter` + `filterUse: radio` + `filterMethod: select` | 下拉框单选 |
| 单选按钮 | `filterType: filter` + `filterUse: radio` + `filterMethod: radioGroup` | 按钮组单选 |
| 多选筛选 / 复选筛选 | `filterType: filter` + `filterUse: checkbox` + `filterMethod: checkboxGroup` | 多选列表 |
| 搜索筛选 / 搜索框筛选 | `filterType: filterSearch` + `filterUse: searchInput` + `filterMethod: searchInput` | 文本搜索输入 |
| 日期范围 / 时间区间 | `filterType: datePicker` + `filterUse: date-range` + `filterMethod: rangeCalendar` | 最常见日期范围 |
| 日期快捷筛选 / 近7天 / 本月 | `filterType: datePicker` + `filterUse: date-period` + `filterMethod: tab` | 快捷区间 |
| 单日期选择 | `filterType: datePicker` + `filterUse: date-calendar` + `filterMethod: calendar` | 单日 |
| 参数输入框 | `filterType: param` + `filterUse: param-input` + `filterMethod: input` | 文本参数 |
| 数字参数输入 | `filterType: param` + `filterUse: param-input-number` + `filterMethod: inputNumber` | 数字参数 |
| 日期参数区间 | `filterType: multipleDateParam` + `filterUse: date-range-step` + `filterMethod: paramDateRange` | 参数化日期范围 |
| 树形过滤器 | `filterType: filterTree` + `treeType: strict` | 默认安全树形 |
| 动态树 | `filterType: filterTree` + `treeType: loose` | 如果用户没明确说“参数”，优先按普通过滤器理解 |
| 参数树 | `filterType: paramTree` + `treeType: strict/loose` | 只有在用户明确说参数控件时再用 |

## 容易混淆的概念

### 1. “地图” 不等于一定能直接做 `Geo`

- 如果用户只是说“地图”，先确认是行政区边界地图还是经纬度 / 多图层地图
- 行政区边界地图通常走 `Geo2D`
- 经纬度点位、连线、热力、多图层叠加更接近 `Geo`
- `Geo` 才有 `mapLayers`；`Geo2D` 不走这套模型
- 两者都需要先确认字段前置条件

### 2. “带小计的表” 不等于随便一个 `Table`

- 如果用户要小计、汇总、展开收起、交叉维度，一般已经进入 table family 的高级配置区
- 此时要明确告诉用户：当前 skill 已固化一部分 rollup / nested axis 写法，但不是完整 table HQL

### 3. “下钻” 可能是两件事

- 点击图表后进入下一层子图：`zoomPath`
- 表格内部层级展开/汇总：table family 的 `drillDown` / rollup

### 4. “动态树” 不是一个独立 `filterType`

- 它更像树形过滤器的一种行为
- 在当前术语里主要体现在 `treeType: loose`

## 推荐响应方式

当用户只给自然语言意图时，优先按下面顺序响应：

1. 先把用户说法翻成候选 chart / filter 术语
2. 明确还要哪些前置条件（字段、指标、geo role、display value）
3. 再给 scaffold / YAML skeleton / validate / apply 的工作流

## 禁止事项

- 不要要求用户必须先说出 `Geo`、`CrossTable`、`KPITrend` 这类内部名字
- 不要把“带小计的表”直接简化成普通明细表
- 不要把“动态树”解释成一个新的 `filterType`
- 不要在术语还没映射清楚前就直接编 YAML
