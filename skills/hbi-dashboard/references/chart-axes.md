# Chart Axes Reference

在以下场景继续读取本参考：

- 需要给 `dashboard plan` 或 `element chart` 写 `chartType` 与 `axes`
- 需要判断 `axes[].name` 是否是前端真实存在的轴位
- 需要从图表类型反推安全模板，而不是凭名称猜维度/度量位置

## 核心结论

- `axes[].name` 应该写前端真实的 `axisName` 值，不要写成自由语义标签
- `kind` 的安全默认值通常是 `formula`，但像 `Boxplot` 的主度量轴这类聚合函数位要显式写成 `kind: function`
- `op` 是 HE 表达式，常见写法是 `"{<field>}"` 或 `sum({<metric_field>})`
- 如果想继承数据集字段上的展示格式，只有 `kind: field` 的轴适合配 `usingDatasetFormatter`
- 对 `kind: formula` 的轴，优先把日期/数字展示格式直接写进 `axes[].formatter`
- 如果数据集字段已经配置了显示值映射（例如 `user_id -> user_name`），图表轴还要显式写 `enableDisplayValue: true`
- Dataset-driven dashboard chart 绑定的是数据集字段和原子指标；6.2 起普通 dashboard chart 也可以通过 `measureSubjectId` 使用主题域业务指标，指标轴写 `kind: measure`。
- 主题域业务指标 ID 来自 `hbi subject list-metrics <subject_id>` 返回的 `id`；不要把 `subject add-metrics` 的 `appId:datasetId:fieldName` 字符串直接写进 chart axis。

## 常见 axisName

| axisName | 常见含义 | 典型 kind | 备注 |
|---|---|---|---|
| `group` | 主分组维度 | `formula` | Bar / Line / Pie 最常见 |
| `groupX` | X 轴分组维度 | `formula` | 双轴或特殊布局图表 |
| `groupY` | Y 方向分组维度 | `formula` | Crosstable / runtime 深层结构里更常见，不要把它当成 Group 系列图表的默认副维度 |
| `subgroup` | 次级分组 | `formula` | table nested 常见；在 Custom / CustomJS 里更偏向深层 runtime，不是当前最稳的 top-level CLI 槽位 |
| `f_subgroup` | 次维度 / 对比分组 | `formula` | BarGroup / AreaGroup / LineGroup / ChordDiagram 常见 |
| `metric` | 主指标槽位 | `formula` | `CustomJS` 主度量轴 |
| `subMetric` | 次指标槽位 | `formula` | `Custom` / `CustomJS` 深层嵌套指标，当前 CLI 更稳的是直接重复主度量槽位 |
| `y` | 主指标轴 | `formula` | Bar / Line / Area 常见 |
| `y1` | 第二指标轴 | `formula` | 双 Y 轴类图表 |
| `size` | 大小/数值轴 | `formula` | Pie / Donut / Bubble 常见 |
| `x` | X 轴数值轴 | `formula` | Scatter / 部分关系图 |
| `color` | 颜色编码轴 | `formula` | 热力/气泡/地图类 |
| `shape` | 形状 / 组合主度量槽位 | `formula` | `Custom` 主度量轴；`style.shapes` 也依赖它 |
| `info` | 附加说明轴 | `formula` | Tooltip / extra info 类 |
| `longitude` | 经度 | `formula` | `Geo` 坐标型图层 |
| `latitude` | 纬度 | `formula` | `Geo` 坐标型图层 |
| `location_start` | 起点地理位置 | `formula` | `Geo` + `arc` + `useLocation: true` |
| `location_end` | 终点地理位置 | `formula` | `Geo` + `arc` + `useLocation: true` |
| `geojson` | 地理对象 | `formula` | GeoJSON 驱动图层 |

如果某个图表类型不在本参考里，不要硬猜；优先退回本参考已覆盖的安全 chartType，或明确说明这个图表的知识还没在 skill 中固化。

## 主题域业务指标轴

普通 dashboard / `element chart` 支持主题域指标作图时，chart 元素使用 `measureSubjectId` 标记主题域，`candidateMeasures` / `sourceMeasureKeys` 标记候选指标和查询 scope，指标轴写成：

```yaml
axes:
  - kind: measure
    op: "<subject_metric_id>"
    name: x
```

规则：

- `<subject_metric_id>` 是 `hbi subject list-metrics <subject_id>` 返回的 `id`。
- CLI 会在生成 runtime 时自动补 `sourceMeasureId`。
- `candidateMeasures` 至少保留 `id`、`appId`、`datasetId`、`fieldName`，这些同样来自 `subject list-metrics`。
- 主题域 chart 不需要顶层 `datasetId` / `dataAppId`；不要为了通过旧校验而伪造 source dataset。
- 只做普通仪表盘里的图表时留在 `hbi-dashboard`；要创建业务指标中心的分析看板资源时才转 `hbi-indicator-center` / `kanban`。

最小 KPI 模板：

```yaml
- type: chart
  chartType: KPI
  title: <title>
  measureSubjectId: <subject_id>
  candidateMeasures:
    - id: <subject_metric_id>
      appId: <metric_app_id>
      datasetId: <metric_dataset_id>
      fieldName: <measure_field_name>
  sourceMeasureKeys:
    - <subject_metric_id>
  axes:
    - kind: measure
      op: "<subject_metric_id>"
      name: x
  layout:
    x: 0
    y: 0
    w: 4
    h: 3
```

## 常见图表的安全轴位组合

| chartType | 常见 axes | 说明 |
|---|---|---|
| `Bar` | `group` + `y` | 最常见的维度 + 指标 |
| `BarStack` | `group` + `y` | 堆叠主要靠 mark / config，不是换轴名 |
| `BarCluster` | `group` + `y` (+ repeated `y`) | 分簇柱状图多指标继续复用 `y` |
| `BarGroupCluster` | `group` + `f_subgroup` + `y` | 分组并列走次维度，不是 `groupY` |
| `BarGroupStack` | `group` + `f_subgroup` + `y` | 分组堆叠同样走次维度 |
| `BarGroupStackPercentage` | `group` + `f_subgroup` + `y` | 百分比分组堆叠也走次维度 |
| `BarHorizon` | `group` + `x` | 横向柱状图的数值轴落在 `x` |
| `BarHorizonCluster` | `group` + `x` | 横向并列多指标复用 `x` |
| `BarHorizonStack` | `group` + `x` | 横向堆叠也走 `x` |
| `BarHorizonStackPercentage` | `group` + `x` | 横向百分比堆叠也走 `x` |
| `Line` | `group` + `y` | 时间/类别 + 数值 |
| `LineBar` | `group` + `y` + `y1` | 柱线组合图分主/副度量槽位 |
| `LineGroup` | `group` + `f_subgroup` + `y` | 分组折线图走次维度 |
| `Area` | `group` + `y` | 与 Line 同类 |
| `AreaGroup` | `group` + `f_subgroup` + `y` | 分组面积图走次维度 |
| `AreaGroupStack` | `group` + `f_subgroup` + `y` | 分组堆叠面积图走次维度 |
| `AreaGroupStackPercentage` | `group` + `f_subgroup` + `y` | 百分比分组面积图走次维度 |
| `BarPolar` | `group` + `value` | 柱状极坐标图走 `value`，不是 `y` |
| `Funnel` | `group` + `size` | 漏斗值轴是 `size`，不是 `y` |
| `Pie` | `group` + `size` | 占比图常见组合 |
| `Donut` | `group` + `size` | 与 Pie 同类 |
| `Polar` | `group` + `size` | 极坐标占比类 |
| `SunBurst` | `group` (+ repeated `group`) + `f_size` | 层级占比类走 `f_size` |
| `Scatter` | `group` (+ repeated `group`) + `x` + `y` (+ `f_size`) | 至少要有 `x` / `y` 两个数值轴 |
| `PackedBubble` | `group` (+ repeated `group`) + `f_size` | 气泡大小槽位走 `f_size` |
| `Gauge` | `size` (+ `min` / `total`) | 仪表盘主值 + 边界槽位 |
| `Radar` | `group` + repeated `size` | 雷达图多指标复用 `size` |
| `Tree` | repeated `group` | 树图层级通过重复 `group` 维度表达 |
| `Treemap` | repeated `group` + `f_size` | 矩形树图层级维度 + `f_size` |
| `Boxplot` | `group` + `y(function box_plot)` | 箱线图主度量轴不是普通 `formula`，要写成 `kind: function` + `op: box_plot` + 单字段 `args` |
| `ArcDiagram` | `group` + `subgroup` | 关系起点/终点维度 |
| `ChordDiagram` | `group` + `f_subgroup` + `size` | 关系对比分组 + 权重 |
| `Sankey` | repeated `group` + `size` | 多级流向节点 + 权重 |

## 安全模板

### Bar

```yaml
- type: chart
  chartType: Bar
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  title: <title>
  axes:
    - kind: formula
      op: "{<dimension_field>}"
      name: group
    - kind: formula
      op: "{<metric_field>}"
      name: y
  layout:
    x: 0
    y: 0
    w: 6
    h: 4
```

### Pie / Donut

```yaml
- type: chart
  chartType: Pie
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  title: <title>
  axes:
    - kind: formula
      op: "{<dimension_field>}"
      name: group
    - kind: formula
      op: "{<metric_field>}"
      name: size
  layout:
    x: 0
    y: 0
    w: 6
    h: 4
```

### Boxplot

```yaml
- type: chart
  chartType: Boxplot
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  title: <title>
  axes:
    - kind: formula
      op: "{<dimension_field>}"
      name: group
    - kind: function
      op: box_plot
      name: y
      args:
        - kind: formula
          op: "{<numeric_field>}"
  layout:
    x: 0
    y: 0
    w: 6
    h: 4
```

`Boxplot` 的 CLI 安全 authoring 面要把主数值轴写成 `box_plot(...)` 函数，而不是把 `y` 轴继续写成普通 `formula`。如果走 `element chart create ... boxplot --measure ...` shorthand，当前稳定写法是单字段或简单单字段聚合（例如 `{sales}`、`sum({sales})`）；不要给 Boxplot 主轴塞复杂多字段公式。

### Custom（组合图）

```yaml
- type: chart
  chartType: Custom
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  title: <title>
  axes:
    - kind: formula
      op: "{<group_dimension>}"
      name: group
    - kind: formula
      op: "{<second_group_dimension>}"
      name: group
    - kind: formula
      op: "sum({<main_metric>})"
      name: shape
      uid: <shape_axis_uid>
    - kind: formula
      op: "avg({<secondary_metric>})"
      name: shape
  style:
    marks: []
    shapes:
      - id: <shape_axis_uid>
        shape: line
  layout:
    x: 0
    y: 0
    w: 6
    h: 4
```

`Custom` 更像组合图 authoring 路径：当前最稳的 top-level contract 是**重复 `group` 维度槽位 + 重复 `shape` 度量槽位**。`shape` 不是普通散点图那种可有可无的装饰轴，而是前端 Custom 路径的主度量槽位。`style.shapes` 通常要和 `shape` 轴的 `uid` 对齐。`subgroup` / `subMetric` 更偏向深层 runtime，不要把它们当成默认 top-level builder 槽位。

### CustomJS（沙盒脚本图）

```yaml
- type: chart
  chartType: CustomJS
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  title: <title>
  code: |
    const chart = params.getEchartsItem();
    chart.setOption({ series: [] });
  axes:
    - kind: formula
      op: "{<group_dimension>}"
      name: group
    - kind: formula
      op: "{<second_group_dimension>}"
      name: group
    - kind: formula
      op: "sum({<main_metric>})"
      name: metric
  style:
    marks: []
  layout:
    x: 0
    y: 0
    w: 6
    h: 4
```

`CustomJS` 的脚本要写在顶层 `code`，不是 `style.custom`。当前最稳的 top-level contract 是**重复 `group` 维度槽位 + `metric` 度量槽位**；`subgroup` / `subMetric` 更偏向深层 runtime，不要默认拿它们当第二个 dimension / measure 槽位。CLI 会把 `code` 直接写到 `options.code`，并限制这个字段只允许出现在 `CustomJS`。

## 高频 `style.marks` / `style.referenceLine` 模板

下面这些不是“唯一合法形状”，但它们最接近前端 seed，适合当安全起点。

### Bar

```yaml
style:
  marks:
    - type: bar
      axisName: y
      groupAxisName: group
  referenceLine:
    - kind: formula
      op: avg({<metric_field>})
      axisName: y
      title: 平均线
```

### Line

```yaml
style:
  marks:
    - type: line
      axisName: y
      groupAxisName: group
      showSymbol: true
  referenceLine:
    - kind: formula
      op: avg({<metric_field>})
      axisName: y
      title: 平均线
```

### Area

```yaml
style:
  marks:
    - type: line
      axisName: y
      groupAxisName: group
      areaStyle: {}
  referenceLine:
    - kind: formula
      op: avg({<metric_field>})
      axisName: y
      title: 平均线
```

### Pie

```yaml
style:
  marks:
    - type: pie
      axisName: size
      groupAxisName: group
```

当前 CLI 会对这几个高频图表给出一层轻量提醒：如果 `style.marks` 明显偏离前端默认主 mark 绑定（例如 `Bar` 没有 `type: bar + axisName: y + groupAxisName: group`），`plan validate` 会发 warning，而不是直接替你猜修。

## 展示格式与显示值

前端图表轴相关的展示信息，至少要分成三层：

- 数据层资源 formatter：`config.formatter.<type>`
- 图表轴级 formatter：`axes[].formatter`
- 图表轴级继承/显示值开关：`usingDatasetFormatter`、`enableDisplayValue`

不要把这三层混成一个 JSON shape。

### 0. 数据层 typed map 和轴层 flat leaf 的区别

数据层 `metric` / `measure`（以及 dataset field metadata）写的是 typed map：

```json
{
  "date": {
    "aggregate": "month",
    "dateFormat": "YYYY-MM",
    "activeKey": "dateFormat"
  }
}
```

轴层 `axes[].formatter` 写的是**内层 leaf**，没有外层 `date` / `number` wrapper：

```yaml
- kind: formula
  op: "month({order_date})"
  name: group
  formatter:
    aggregate: month
    dateFormat: YYYY-MM
    activeKey: dateFormat
```

两层复用同一套 `DisplayFormatter` leaf 字段，但外层 shape 不同。

### 1. Formula 轴显式写 formatter

```yaml
- kind: formula
  op: "{<order_date>}"
  name: group
  formatter:
    aggregate: month
    dateFormat: YYYY-MM
    activeKey: dateFormat
```

这类写法最适合 formula 轴，因为它不依赖字段继承逻辑。

### 2. Field 轴继承数据集 formatter

```yaml
- kind: field
  op: order_date
  name: group
  usingDatasetFormatter: true
```

只有当轴本身真的是 `kind: field` 时，这种继承才可靠。前端 `getAxisFormatter()` 会在这一分支里去读字段/指标元数据上的 `config.formatter.<type>`，再解析成轴级 leaf formatter。

### 3. 轴启用显示值映射

```yaml
- kind: field
  op: user_id
  name: group
  enableDisplayValue: true
```

这个开关只负责告诉前端“这里要显示 display value，而不是原始值”。真正的映射关系仍然来自数据集字段上的 `displayConfig`。

### 4. `axes[].formatter` 的 stable leaf 字段

`axes[].formatter` 与数据层 `config.formatter.<type>` 的 inner value 复用同一套 flat 字段：

#### 常见 number / date leaf 字段

| 字段 | 含义 | authoring 提示 |
|---|---|---|
| `prefix` | 前缀文本 | 稳定，可直接写 |
| `suffix` | 数值单位/缩写选择值 | 对应前端单位 selector；不是自由文本后缀 |
| `percent` | 百分比标记 | 常见值是 `%` |
| `unit` | 自定义后缀文本 | 稳定，可直接写 |
| `fillInDecimalPlaces` | 是否补齐小数位 | `true` 时按 `decimal` 补位 |
| `thousands` | 是否启用千分位 | 数字场景高频 |
| `decimal` | 小数位数 | 常见范围 `0..20` |
| `scientificNotation` | 是否启用科学计数法 | 通常与 `fillInDecimalPlaces` 二选一 |
| `showPlus` | 正数是否显示 `+` | 数字场景可直接写 |
| `showSuffix` | 是否显示 `suffix` 单位 | 兼容字段；KPI 更常见 |
| `aggregate` | 日期/时间格式对应的聚合粒度 | 常见如 `day` / `month` / `year` |
| `defaultAggrType` | `aggregate` 的 alias / 默认聚合回退 | 更偏回读/兼容；新 authoring 通常直接写 `aggregate` |
| `dateDowFormat` | 星期展示格式 | 例如短星期/长星期 |
| `dateNumberFormat` | 数字日期格式 | 优先跟现有导出值走 |
| `dateFormat` | 主日期格式模板 | 例如 `YYYY-MM`、`YYYY-MM-DD` |
| `activeKey` | 当前启用的日期格式字段 | 只应是 `dateFormat` / `dateDowFormat` / `dateNumberFormat` 之一 |

#### `null_format` / `empty_format`

| 子字段 | 含义 | authoring 提示 |
|---|---|---|
| `type` | 替换模式或预设值 | 安全自定义写法是 `custom`；其它 preset 更适合从导出值复用 |
| `format` | 自定义替换文本 | 仅当 `type = custom` 时需要 |

#### `desensitization`

| 子字段 | 含义 | authoring 提示 |
|---|---|---|
| `prefix` | 前缀保留字符数 | 数字 |
| `suffix` | 后缀保留字符数 | 数字 |
| `mode` | 脱敏模式 | 前端已知值包括 `none` / `all` / `single` |
| `replaceValue` | 替换字符或预设 | 常见如 `*` / `X` / `custom` |
| `customValue` | 自定义替换字符 | 仅当 `replaceValue = custom` 时需要 |

#### 兼容 / 保留字段

| 字段 | 含义 | authoring 提示 |
|---|---|---|
| `formulaType` | formula 派生 formatter subtype | 偏 runtime/兼容字段；优先保留，不要凭空造 |
| `mode` | legacy flat 替换模式 | 新 authoring 优先写 `desensitization.mode` |
| `replaceValue` | legacy flat 替换字符 | 新 authoring 优先写 `desensitization.replaceValue` |
| `customValue` | legacy flat 自定义替换字符 | 新 authoring 优先写 `desensitization.customValue` |
| `nullReplace` | legacy dataset null replacer 对象 | 新 authoring 优先用 `null_format` / `empty_format` |

### 5. 最稳妥的继承规则

1. 数据层写 formatter：`config.formatter.<type> = <DisplayFormatter leaf>`
2. chart `kind: field` 轴要复用数据层 formatter：写 `usingDatasetFormatter: true`
3. chart `kind: formula` 轴不要开 `usingDatasetFormatter`：把同一个 leaf 直接写进 `formatter`
4. `enableDisplayValue` 与 formatter 独立：它只决定“显示 display value 还是原始值”，不负责日期/数字格式

## 当前已固化

- 当前 plan 已能稳定表达一批关键轴字段：`uid`、`formatter`、`usingDatasetFormatter`、`enableDisplayValue`、`layer`、`args`、`labels`、`position`、`rollupType`、`columnStyleId`、`isFolded`、`hidden`、`isNestingAxis`、`axisGroup`、`nested`、`isNestCombine`、`redirectType`
- 这些字段已经足够表达 table family 里最关键的几类高级轴：顶层 `rollup`、嵌套 `subgroup` / `rollup` 子轴、列样式引用、折叠/隐藏状态，以及 Geo 图层绑定
- `columnStyleId` 属于已经稳定的 table-family axis slice；如果目标是列样式、rollup、nested subgroup 这类表格结构问题，优先复用这批已固化字段，而不是跳到更深的 HQL 轴模型

## 当前未固化 / 不要假设

- 完整 HQL 轴模型：`typedFormatter`、`formatterOrigin`、`growthCalculation`、复杂 cell formula 等仍属于边界外
- 即使 runtime 里能看到 `typedFormatter` / `formatterOrigin`，也不要把它们误当成当前稳定 plan authoring 字段；当你需要的是普通 number/date formatter，优先继续用 `formatter` / `usingDatasetFormatter`
- 如果用户要的是同环比 / 增长率 / 更深的 formatter migration 语义，先把表格基本结构用当前 plan 落好，再明确说明这些 `typedFormatter` / `formatterOrigin` / `growthCalculation` 级字段仍要回前端表格编辑能力处理，不要在 CLI 里臆造
- 每个冷门图表的可直接套用模板；当前文档主要覆盖常用 cartesian、part-to-whole 基础组合、table family 高级轴，以及 Geo 图层绑定
- 稀有 relation / trip / flow / location 图表的逐个 authoring 规则
- `axisConf`、`mobileOptions` 等更深层 runtime，以及 `style.marks` / `style.shapes` / `style.referenceLine` 的逐项语义校验与 family 最佳实践
- `style.shapes` 的完整 cookbook；当前它更接近 Custom chart 的 `shape` 轴运行时，而不是所有普通图表都同等成熟的通用配置
- `Custom` 的 `dataZooms` / `autoRefresh`，以及 `CustomJS` 完整 helper API 的 cookbook 还没有固化成 plan 安全子集

## Table family 的高级轴写法

当目标是 `Table` / `CrossTable` / `DatasetTable` 时，`axes[]` 不再只是扁平的一维数组。

### 顶层 rollup 轴

```yaml
- kind: function
  op: rollup
  name: groupX
  uid: <rollup_uid>
  position: groupX
  rollupType: dimensions
  labels: [null, <rollup_label>]
  args:
    - []
    - - op: <dimension_axis_uid>
          rollupType: dimensions
```

### 度量上的嵌套 subgroup / rollup

```yaml
- kind: formula
  op: "sum({<metric_field>})"
  name: size
  isNestingAxis: true
  nested: <group_name>
  isNestCombine: false
  args:
    - name: subgroup
      kind: formula
      op: "{<contrast_dimension_field>}"
    - op: rollup
      kind: function
      rollupType: metrics
      labels: [null, <rollup_label>]
      args:
        - []
        - - op: <dimension_axis_uid>
            rollupType: dimensions
```

这里的 `labels: [null, ...]` 很关键：第一个 `null` 代表明细层，不要被清理掉。

## Geo family 的轴绑定

`Geo` 和普通柱线图不一样：轴要绑定到具体地图图层。`Geo2D` 不走这套模型，不要给 `Geo2D` 写 `mapLayers` 或 `axes[].layer`。

```yaml
- type: chart
  chartType: Geo
  datasetId: <datasetId>
  axes:
    - kind: formula
      op: "{<region_field>}"
      name: group
      layer: china_layer
    - kind: formula
      op: "sum({<metric_field>})"
      name: size
      layer: china_layer
  geoRuntime:
    mapLayers:
      - type: polygon
        layerUid: china_layer
```

关键点不止一个：

- `axes[].layer` 必须和 `geoRuntime.mapLayers[].layerUid` 对上
- `Geo` 的 layer type 决定允许的轴位组合；不要把 `point` 图层写成 `group + size` 再配 `useLocation: false`
- `useLocation: true` 会改变部分 layer 的默认 seed 和轴位要求

常见安全组合：

- `polygon`：`group` + `size`
- `solid_polygon`：`group` + `geojson` + `size`
- `point` / `hexbin` / `heatmap` / `grid` / `cluster`
  - 坐标型：`longitude` + `latitude` + `size`
  - `useLocation: true`：`group` + `size`
- `marker`
  - 坐标型：`longitude` + `latitude`
  - `useLocation: true`：`group`
- `arc`
  - 坐标型：`longitude_start` + `latitude_start` + `longitude_end` + `latitude_end`
  - `useLocation: true`：`location_start` + `location_end`
- `trip`
  - 坐标型：`trip_id` + `trip_time_series` + `longitude` + `latitude`
  - `useLocation: true`：`trip_id` + `trip_time_series` + `group`

## 禁止事项

- 不要把 `axes[].name` 写成 `dimension`、`measure` 这类自由标签
- 不要只看图表名称就臆造轴位；先用本参考里的安全组合，超出覆盖面时明确说“当前 skill 未固化”
- 不要把前端完整 chart config 当成 plan 已完整支持
