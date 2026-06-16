# Dashboard Plan Reference

在以下场景继续读取本参考：

- 需要用 YAML 一次性创建或更新整页仪表盘
- 需要把现有仪表盘 / page / report 导回可编辑 plan
- 需要处理 container / tab / 嵌套控件
- 需要把仪表盘结构纳入版本管理
- 需要知道 `dashboard plan apply` 与手工 `element` 命令的边界

如果需要更细的字段/轴位定义，再继续读取：

- `terminology-map.md`：把“趋势图”“带小计的表”“地图”“动态树”这类自然语言需求翻成 plan 术语
- `chart-axes.md`：图表 `chartType`、`axes[].name`、常见轴位组合
- `filter-config.md`：过滤器运行时字段、`filterType/use/method`、plan 能表达的最小子集
- `dashboard-runtime.md`：`dashboard show` JSON、布局对象、container/tab、设备配置

## 命令形态

```bash
hbi dashboard plan scaffold --app <app_id> --dataset <dataset_id> > plan.yaml
hbi dashboard plan scaffold --app <app_id> --dataset <dataset_id> --chart-type Bar > plan.yaml
hbi dashboard plan validate --file plan.yaml --app <app_id>
hbi dashboard plan apply --file plan.yaml --app <app_id>
hbi dashboard plan apply --file plan.yaml --app <app_id> --name "覆盖标题"
hbi dashboard plan apply --file plan.yaml --app <app_id> --update <dashboard_id>
hbi dashboard plan export --app <app_id> --dashboard <dashboard_id> --output yaml > exported-plan.yaml
```

含义：

- `scaffold`：读取 dataset fields + atomic metrics，输出一个可编辑 plan 骨架
- `validate`：读取 plan 里实际引用的数据集，检查字段、原子指标、Geo 前置条件、display value 前置条件，并输出修复提示
- 不传 `--update`：先创建仪表盘，再按 YAML 打 patch
- 传 `--update`：先读取现有仪表盘，再按目标状态计算增量 patch
- 传 `--name`：覆盖 YAML 里的 `dashboard.name`
- `export`：把现有 dashboard runtime 回推成可编辑 plan YAML，适合从已存在的 analytic / page / report stable subset 继续 authoring

## 心智模型

`dashboard plan` 不是单个控件的快捷包装，而是“整页仪表盘声明式构建”。

当前实现做了五件事：

1. 用 `scaffold` 基于字段/指标元数据生成一份安全起稿
2. 用 `validate` 在 apply 前检查 plan 引用的前置条件
3. 用 `export` 从现有 runtime 回推一个更贴近真实页面的 plan 起点
4. 解析 YAML 为 `DashboardPlan`
5. 按 create 或 update 路径把计划文件转换成 dashboard options / patches

如果 update 路径算出来没有差异，命令会直接退出，不会强行重写。

## 当前稳定 shell coverage

`dashboard plan` 现在不是只覆盖 analytic dashboard 了，但不同 shell 的稳定面并不一样：

- **analytic dashboard**：仍然是最完整、最通用的 plan surface
- **page dashboard**：当前已支持 stable shell roundtrip，适合 `export -> edit -> validate -> apply`
- **report dashboard**：当前只支持较窄的 stable subset

report 的当前稳定 subset 是：

- 顶层 `dashboard.type: report`
- 顶层 `dashboard.dataAppId` / `dashboard.datasetId`
- zero or more 顶部 root `filter`
- zero or one 底部 `ComplexTable`
- shell-managed outer `filterBtn` 继续视为 backend-seeded runtime，不当成自由 authoring 面

如果用户要的是**新建 blank report shell**，仍然先走：

```bash
hbi dashboard create --dashboard-type report --data-app <data_app_id> --dataset <dataset_id> --app <report_app_id> "月报"
```

不要把 `plan scaffold` 当成 report shell create 的替代。

## Scaffold 的定位

`scaffold` 不是“最终答案”，而是把最常见的前置 discovery 结果物化成一份更容易编辑的 YAML 草稿。

当前行为：

- 读取 `dataset fields` 和 `metric list`，并把字段用途 / 展示格式 / display value 摘要写进 YAML 顶部注释
- 优先生成 `kind: field` 的轴，避免一上来就把字段写成 `kind: formula`，这样 `usingDatasetFormatter` / `enableDisplayValue` 更容易和数据集元数据对齐
- 当字段或指标已有展示格式时，优先写 `usingDatasetFormatter: true`
- 当筛选字段已有 display value 映射时，会在 filter 元素上补 `enableDisplayValue: true`
- 若未显式指定 `--chart-type`，会按字段/指标形态做保守推断：
  - timestamp + metric → `Line`
  - dimension + metric → `Bar`
  - dimension-only → `Table`
  - metric-only → `Kpi`

当前刻意只覆盖一组安全 chartType：

- `Line`
- `Area`
- `Bar`
- `Pie`
- `Donut`
- `Table`
- `DatasetTable`
- `Kpi`
- `KpiTrend`

`scaffold` 生成之后，仍然应该按真实需求继续补：

- `layout`
- `style`
- family-specific runtime（如 `tableRuntime` / `kpiRuntime` / `geoRuntime`）
- 真实过滤条件、排序、钻取和交互配置

## Validate 的定位

`validate` 是 preflight 到 apply 之间的闸门，不是多余的一层。

当前会重点检查：

- chart / filter 引用的字段名是否真实存在
- 图表里引用的原子指标是否已定义
- `enableDisplayValue: true` 是否对应到了已配置 display value 的字段
- Geo 图是否已经绑定到带地理角色的字段
- family-specific runtime 和 `chartType` 是否匹配

如果 plan 仍然带着 `"{<field>}"` 这种占位符，或者写了不存在的 `c9` / `m1`，优先让 `validate` 报出来，再回头修 plan 或补前置能力；不要直接 `apply` 再去 GUI 里猜。

当前 `validate` 只负责**提前发现问题并给出修复提示**，还不会自动修复缺失 metric、geo role 或 display value 前置条件。

## 推荐执行顺序

1. 跑 `hbi dataset fields --app <app_id> --dataset <dataset_id>` 看 `Purpose` / `Format` / `Display Value` / `Geo Role`
2. 跑 `hbi metric list --app <app_id> --dataset <dataset_id>` 看 atomic metrics
3. 从 `dashboard plan scaffold` 或本参考的最小 skeleton 起草 YAML
4. 补 family-specific runtime、过滤器、布局、交互配置
5. 跑 `hbi dashboard plan validate --file plan.yaml --app <app_id>`
6. 通过后再 `apply`
7. 用 `dashboard show --output json` 回查 post-condition

## 顶层 YAML 结构

```yaml
dashboard:
  name: 销售仪表盘
  grid:
    columns: 12
    margin: 10
  pc:
    w: 12
    h: 90
    gap: 10
    scale: fixed
    scaleMode: origin
    theme:
      base: CLASSIC
  mobile:
    mode: auto
    w: 6
    gap: 10
    scale: "1*1"
    scaleMode: origin
    theme:
      base: CLASSIC
  theme:
    backgroundColor: "#ffffff"
  elements:
    - type: chart
      ...
```

字段约定：

- 全部使用 `camelCase`
- `grid` 和 `theme` 可省略，省略时走默认值
- `pc` / `mobile` 是当前 plan 已支持的顶层 device 安全子集
- 如果要固定尺寸画布，显式写 `dashboard.sizeMode: fixed`，再在 `pc` / `mobile` 下写 `width` / `height`，必要时补 `scaleMode` / `scaleAlign`
- fixed-size authoring 只写逻辑布局和 device 画布参数；CLI 会自动生成 runtime `pxLayouts` / `pxMobileLayouts`，不要在 plan 里手写这两个分支
- `unlimitedWidth` / `unlimitedHeight` 这类更深 fixed-size mode 选项当前仍不属于稳定 plan surface
- `grid.columns` / `grid.margin` 仍会作为 `config.pc.w` / `config.pc.gap` 的默认回退；如果同时显式写了 `pc.w` / `pc.gap`，以 `pc.*` 为准
- `description` / `folderId` / `grid.rowHeight` / `theme.accentColor` 当前仍只算 schema 接收，不属于最小稳定 skeleton
- `elements` 是整个计划文件的核心
- `dashboard.page` 不再属于稳定 authoring 面；它对应旧高级仪表盘的 `options.page` 兼容字段，show payload 里可能还能看到，但新 plan 不应继续写它

当前仍然只保证 **schema 接收**、不保证 `apply` 已完整落盘的顶层字段主要是：

- `description`
- `folderId`
- `theme.accentColor`
- `grid.rowHeight`

## 当前支持的控件类型

顶层 `elements[].type` 目前支持：

- `chart`
- `button`
- `filter`
- `container`
- `text`
- `image`

## 各类控件的关键字段

### Chart

最常用字段：

- `chartType`
- `datasetId`
- `dataAppId`
- `measureSubjectId`
- `candidateMeasures`
- `sourceMeasureKeys`
- `title`
- `code`（仅 `CustomJS`）
- `axes`
- `filters`
- `sort`
- `style`
- `drillDown`
- `clickHandler`
- `mouseAction`
- `redirect`
- `zoomPath`
- `tableRuntime`
- `kpiRuntime`
- `geoRuntime`
- `pager` / `autoScroll` / `cellContent`（主要对 table family 有用）
- `layout`

`dataAppId` 是承载 `datasetId` 的 source data-app；不要把它和 `--app` / dashboard app id 当成同一个值。

如果图表使用主题域业务指标，元素写 `measureSubjectId`，并用 `candidateMeasures` / `sourceMeasureKeys` 描述 `hbi subject list-metrics <subject_id> --limit 20 --output json` 返回的当前页候选指标。此模式不需要 `datasetId` / `dataAppId`；指标轴写 `kind: measure`，`op` 使用 `subject list-metrics` 返回的 metric-folder `id`。

`axes` 每项至少包含：

- `kind`
- `op`
- `name`

写图表时不要凭空发明轴语义；`axes[].name` 优先参考 `chart-axes.md` 里已经固化的 axisName 与值域，不要写成自由发挥的语义标签。
如果用户没有给出真实 schema，`axes[].op` 也必须写成占位符，例如 `{<dimension_field>}`、`{<metric_field>}`，不要自动写成 `{month}`、`{sales}`、`{region}`。
如果目标是时间分组，优先写真实 HQL，例如 `day({created_at})` / `month({created_at})` / `trunc_month({created_at})` 这类日历函数；不要把日期字段先 `substring(...)`、`date_format(...)` 成字符串再分组，也不要把 `field:granularity` 这种命令级 shorthand 混进 chart / plan 表达式里。
图表元素常用展示字段是 `title`，不要臆造 `name` 当成计划文件里的稳定字段。
如果用户只要求“给我一个模板”，优先给最小 skeleton，不要把业务字段、筛选条件、排序条件一次性补满。

主题域指标 KPI 最小 skeleton：

```yaml
dashboard:
  name: 指标主题域页面
  elements:
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

先跑 `hbi subject list-metrics <subject_id> --limit 20 --output json` 拿真实 `id/appId/datasetId/fieldName` 样例，并读取分页 envelope 的 `total` / `hasMore`；不要把 `subject add-metrics` 的 `appId:datasetId:fieldName` 字符串当作 axis op，也不要用 `--all` 把全量候选塞进 plan。
`style` 只应记录当前 CLI 真正会落到 patch 的安全子集；详细覆盖边界见 `chart-axes.md`。
除了通用图例 / 颜色 / 轴 / tooltip / title / label 这类 `custom` 子树外，`style` 现在还支持一小批直接写到 chart 顶层 runtime 的高级字段：

- `marks`
- `shapes`
- `referenceLine`

这三类字段会分别落到 `options.marks` / `options.shapes` / `options.referenceLine`，更适合 ECharts 类图表的精细样式控制。当前 CLI 对它们主要做结构透传 + 少量关键结构校验；写之前仍要以前端真实字段形状为准。

其中：

- `marks` 是大多数高频图表（Bar / Line / Area / Pie 等）最常用的细粒度样式入口
- `referenceLine` 主要是轴类图表的参考线 runtime
- `shapes` 目前更接近前端 custom-shape 运行时，通常要和 `axes[].name: shape`（常见于 Custom chart 路径）一起理解；没有 `shape` 轴时，plan validate 会给出提醒
- `code` 不属于 `style`；它是 `CustomJS` 的顶层 chart 字段，CLI 会直接写到 `options.code`
- `plan validate` 现在还会做一层轻量结构检查：
  - `marks[]` 必须是 object，且 `type` 必填
  - `marks[].axisName / groupAxisName / subgroupAxisName / percentAxisName` 如果出现，就必须引用当前图上真实存在的轴
  - `Bar / Line / Area / Pie` 如果明显偏离前端默认主 mark 绑定，会收到 warning

两类强自定义图表现在建议这样理解：

- `Custom`：组合图 / ECharts authoring 路径。当前最稳的 top-level contract 是重复 `group` 维度槽位 + 重复 `shape` 度量槽位，再配合 `style.marks` / `style.shapes`。`subgroup` / `subMetric` 更偏向深层 runtime，不要默认把第二个 dimension / measure 写成这两个顶层轴位。CLI 还没有把前端 `dataZooms` / `autoRefresh` 抽成专门 plan 字段。
- `CustomJS`：沙盒脚本图表。当前最稳的 top-level contract 是重复 `group` 维度槽位 + `metric` 度量槽位，加顶层 `code: |` 脚本块；`subgroup` / `subMetric` 更偏向深层 runtime，不要默认拿它们做第二个 top-level 槽位。CLI 会把脚本直接写到 `options.code`，并限制它只用于 `CustomJS`。
`axes[]` 现在还支持一组展示格式 / 显示值字段：

- `formatter`：显式写入轴级展示格式；这里吃的是 flat `DisplayFormatter` leaf，不带外层 `number` / `date` typed wrapper
- `usingDatasetFormatter`：让轴继承 dataset field / atomic metric 上的 `config.formatter.<type>`，只建议配合 `kind: field`
- `enableDisplayValue`：让图表轴展示数据集字段的显示值映射，而不是原始 key / id

稳妥规则直接记这三条：

1. 数据层 formatter：`config.formatter.<type> = <leaf>`
2. `kind: field` 轴想复用数据层 formatter：`usingDatasetFormatter: true`
3. `kind: formula` 轴：直接把同一个 leaf 写进 `axes[].formatter`

`usingDatasetFormatter` 不是万能继承开关：对 `kind: formula` 的轴，不要依赖它来继承字段展示格式。此时更稳妥的写法是把需要的日期/数字格式直接写进 `axes[].formatter`。
`enableDisplayValue` 和 formatter 不是一回事：前者解决的是 `id -> username` 这类显示值映射，前提是数据集字段本身已经配置了 `enableDisplayValue + displayConfig`；后者解决的是日期/数字如何格式化显示。
如果你手里拿到的是 `metric` / `measure` 的 `--display-format` JSON，记住轴层不能直接照抄外层 typed map：`{"number": {...}}` 要去掉 wrapper，只把 inner leaf 放进 `formatter`。完整字段说明继续看 `chart-axes.md`。
`clickHandler` 只是点击行为枚举：`mouseAction` 负责菜单/脚本等点击细节，而 `redirect` 负责 chart 顶层 `options.redirect` 跳转载荷。当前 CLI 已经把 `clickHandler: redirect` + `redirect` 固化成稳定 chart authoring slice，适合表达跳仪表盘/URL 这类 chart 交互。
`zoomPath` 现在支持作为递归 chart config 子集写入 plan。CLI 会以父层图表配置为基底，再用子层显式给出的字段覆写，和前端“添加下钻层时复制当前图表配置再编辑”的行为对齐；如果子层切换到了不兼容的 chart family，CLI 会先清理父层继承下来的 table / geo 专属 runtime 字段，再应用子层覆写。
`zoomPath` 和 table 自带的 `drillDown` 不是一回事：前者是点击后切换到下一层子图表配置，后者是表格自身的分组/上卷/下钻行为。
`tableRuntime` 现在用于承载 table family / complex table 的高级 runtime 子集，包括：

- `custom`
- `datasetName`
- `queryCategory`
- `fieldsPolicy`
- `columnStyle`
- `columnStyleMapper`
- `rowRollup`
- `columnRollup`
- `rollupInfo`
- `pivot`
- `dimsFolded`
- `contrastDimsFolded`
- `template`
- `page`
- `otherCellInfos`
- `groupByCellInfos`

`kpiRuntime` 现在用于承载 `KPI / KPITrend` 的特殊 runtime 子集，包括：

- `custom`
- `marks`
- `tooltip`

其中 `custom` 对应前端 KPI family 的 `layout / group / main / minor / contrast` 这类 seed/runtime 结构；如果只是通用图例、标题、颜色，不要塞进 `kpiRuntime`，继续用通用 `style`。

`geoRuntime` 现在用于承载 Geo family 的特殊 runtime 子集，但 `Geo` 和 `Geo2D` 不是同一套地图模型：

- `Geo`：`mapConf` / `mapLayers` / `tooltip` / `autoRefresh`
- `Geo2D`：`legends` / `marks` / `tooltip` / `autoRefresh`

其中 `mapLayers` 只属于 `Geo`。CLI 会按 layer type 补齐前端需要的 `axisConf` 骨架，并在 plan 阶段校验：

- `axes[].layer` 必须引用已声明的 `mapLayers[].layerUid`
- `layerUid` 不能重复
- 每个已绑定图层只能使用该 layer type 允许的轴位组合
- 每个已绑定图层必须补齐该 layer type 的必需轴位

### Chart family matrix

| Family | Typical chartType | Special runtime block | Family-specific axes |
| --- | --- | --- | --- |
| cartesian | `Bar` / `Line` / `Area` | none | none |
| table | `Table` / `CrossTable` / `DatasetTable` / `ComplexTable` | `tableRuntime` | `args` / `labels` / `position` / `rollupType` / `columnStyleId` / `isNestingAxis` |
| kpi | `KPI` / `KPITrend` | `kpiRuntime` | none |
| geo | `Geo` | `geoRuntime` | `layer` |
| geo | `Geo2D` | `geoRuntime` | none |
| part-to-whole / hierarchy / relation | `Pie` / `Treemap` / `Sankey` | none | none |

CLI 现在会按这张 family matrix 做基础校验：把 `tableRuntime` 塞到 `Bar`、把 `geoRuntime.mapLayers` 塞到 `Geo2D`、让 `axes[].layer` 指向不存在的地图图层，或者给某个 Geo 图层写错轴位组合，都会在 plan 阶段直接报错，而不是等到 GUI 才暴露。

写 `Table` / `CrossTable` / `DatasetTable` 时，如果需要列样式生效，通常还要在 `axes[]` 里同时写 `columnStyleId`；只写 `tableRuntime.columnStyle` 而不在轴上挂引用，很多配置不会真正落到单元格上。
`axes[]` 现在还支持一批 family-specific 的高级字段：

- `layer`（Geo 图层绑定）

- `args`
- `labels`
- `position`
- `rollupType`
- `columnStyleId`
- `isFolded`
- `hidden`
- `isNestingAxis`
- `axisGroup`
- `nested`
- `isNestCombine`
- `redirectType`

其中最重要的是：

- `rollup` 轴通常表现为 `op: rollup` + `rollupType` + `labels` + `args`
- 度量上的对比/小计通常表现为 `isNestingAxis: true`，并把 `subgroup` / `rollup` 这类子轴放进 `args`
- Geo chart 的轴不是“全局轴”；`axes[].layer` 要显式绑定到 `geoRuntime.mapLayers[].layerUid`
- `Geo2D` 不使用 `mapLayers`；如果你要的是二维区域着色地图，优先想 `group + color`，而不是经纬度 / layer 绑定

即便如此，当前 plan 仍然**不是**前端完整 HQL 轴模型的等价镜像；轴级 `formatter` / `usingDatasetFormatter` 这一层已经可以表达，但更深的 `typedFormatter`、`formatterOrigin`、`growthCalculation`、复杂 cell formula 等仍属于高级边界，不能假装“任意复杂表格都已经完全可生成”。

### Filter

最常用字段：

- `filterType`
- `filterField`
- `filterMultiple`
- `filterUse`
- `filterMethod`
- `treeType`
- `filterOptions`
- `datasetId`
- `dataAppId`
- `layout`

这只是当前 plan 的最小子集。前端运行时过滤器的真实结构远比这里丰富，涉及 `use`、`method`、`options`、`fieldSiblings`、`operator`、`dateRange` 等字段时，继续看 `filter-config.md`。

### Button

最常用字段：

- `title`
- `layout`
- `buttonStyle`
- `buttonEvents`
- `buttonOptions`

推荐先把 button authoring 收敛在这几类稳定高频事件：

- `refresh`
- `full_screen`
- `control_container`
- `jump`

当前 `buttonEvents` 支持的是完整 `ButtonEventSpec` 安全子集，而不只是上面四个高频例子：`jump`、`scroll_to`、`control_container`、`full_screen`、`export`、`refresh`、`print`、`runJS` 都是稳定入口。

字段映射：

- `buttonStyle -> layout.options.style`
- `buttonEvents -> layout.options.events`
- `buttonOptions -> layout.options` 里的剩余子字段（例如 `clickHandler`）
- 不要把这里的 `layout.options.events` 推广成所有 element 都有同等成熟的通用事件 authoring 面；当前这是 button 的稳定合同，不是任意 layout item 的通用合同
- 前端虽然在 runtime/model 层声明了通用 `LayoutOption.events`，但当前 item-setting editor 真正写这个字段的仍然只有 button；text / image / shape 的交互编辑面不是 `events[]`，而是另一套 `clickHandler` / `redirect` / `customJS` / `scrollControl` / `controlContainer*` / hover 字段

一个最小示例：

```yaml
- type: button
  title: 刷新
  buttonStyle:
    background: "#5C6FD7"
    color: "#ffffff"
  buttonEvents:
    - type: refresh
  buttonOptions:
    clickHandler: 2
  layout:
    x: 0
    y: 0
    w: 2
    h: 1
```

### Container

最常用字段：

- `title`
- `layout`
- `containerOptions`
- `containerTabs`

`containerOptions` 现在承载 container 运行时里最值得稳定 author 的那一层：

- `activeTabIndex`
- `tabsOptions`
- `style`
- `mobileOptions`
- `config`

`containerTabs` 下每个 tab 至少包含：

- `title`
- `config`
- `elements`

其中：

- `containerOptions.tabsOptions` / `style` / `mobileOptions` / `config` 当前按安全透传处理，写之前仍应以前端 runtime 结构为准
- `containerTabs[].config` 会写到对应 `tabMap[].options.config`
- tab / container 级的 `charts` / `filters` 运行时列表由 CLI 按嵌套元素自动维护；不要在 plan 里手工编造这些 ID 列表

`container` / `tab` 的运行时 JSON 结构、`tabsOptions`、`layouts` 映射和 PC/移动端布局差异，继续看 `dashboard-runtime.md`。

### Text

最常用字段：

- `textContent`
- `textSlate`
- `textAlign`
- `layoutOptions.titleStyle`
- `layoutOptions.stylesAtDashboard`
- `layoutOptions.clickHandler`
- `layoutOptions.redirect`
- `layoutOptions.customJS`
- `layoutOptions.scrollControl`
- `layoutOptions.controlContainerId`
- `layoutOptions.controlContainerTab`
- `layout`

`textContent` 仍然是 Markdown sugar；CLI 会把它转换成前端运行时使用的富文本 JSON，并保留文本里的 `{{formula}}` 公式节点。

`textSlate` 是高保真路径：

- 推荐写 canonical Slate array form
- 也兼容前端旧 runtime wrapper（`document.nodes`）导入
- CLI 会在保存前归一化成前端兼容的 runtime wrapper

`element text show --as-spec` / container 嵌套 text 导出时：

- 如果当前内容能无损回到 Markdown，会继续导出 `textContent`
- 如果当前只是统一 block 对齐差异，也会额外导出 `textAlign`
- 如果包含 Markdown 无法表达的样式/结构，则导出 `textSlate`

`textAlign` 当前只承诺统一 block 对齐这一层安全子集；更复杂的逐段样式、混合对齐和富文本装饰仍然应该回到 `textSlate`。

`layoutOptions` 在 text 上的当前稳定交互子集是：

- `clickHandler`
- `redirect`
- `customJS`
- `scrollControl`
- `controlContainerId`
- `controlContainerTab`

其中：

- `clickHandler` 当前按前端 `CONTROL` 常量暴露成可读 token，例如 `redirect`、`custom-js`、`scroll-to`、`control-container`
- `redirect` 直接对应 `layout.options.redirect`，包括 `type`、`dashboardId`、`dashboardType`、`with/withoutFilter`、`filterSetting`、`url`、`targetBlank`、`popupSize`、`showCloseBtn`
- `customJS` 会落到 `layout.options.customJS`
- `scrollControl` / `controlContainerId` / `controlContainerTab` 也是稳定透传字段，但它们通常更适合 `plan export -> edit -> apply --update` 这类 workflow；当前 plan 没有“稳定元素锚点”可让你在全新页面里安全臆造目标控件 id

### Image

最常用字段：

- `imageUrl`
- `imageFit`
- `layoutOptions.titleStyle`
- `layoutOptions.stylesAtDashboard`
- `layoutOptions.clickHandler`
- `layoutOptions.redirect`
- `layoutOptions.customJS`
- `layoutOptions.scrollControl`
- `layoutOptions.controlContainerId`
- `layoutOptions.controlContainerTab`
- `layout`

`imageUrl` 现在既可以是远程 URL，也可以是已上传 dashboard image 的 numeric 资源 ID。

`imageFit` 会落到前端真实 runtime 顶层 `imageSize`，而不是旧的 `options.fit`；当前默认值对齐前端 add-image 行为，未显式写时按 `contain` 处理，并自动补 `position-x = center`、`position-y = center`。

`image` 的 `layoutOptions` 交互子集和 `text` 同步：

- `clickHandler`
- `redirect`
- `customJS`
- `scrollControl`
- `controlContainerId`
- `controlContainerTab`

这里也要沿用同一条规则：`scrollControl` / `controlContainer*` 在 contract 上是稳定字段，但新建 dashboard 时不要凭空编造目标 id；如果是改现有页面，优先先 `dashboard plan export` 再编辑回写。

### Shape

最常用字段：

- `shapeType`
- `shapeOptions`
- `layoutOptions.titleStyle`
- `layoutOptions.clickHandler`
- `layoutOptions.redirect`
- `layoutOptions.customJS`
- `layoutOptions.scrollControl`
- `layoutOptions.controlContainerId`
- `layoutOptions.controlContainerTab`
- `layoutOptions.actionType`
- `layoutOptions.hoverHandler`
- `layoutOptions.hoverAction`
- `layout`

当前 shape 的 plan surface 明确拆成两层：

- `shapeOptions` = shape appearance/runtime 子集，当前稳定字段包括：
  - `proportion`
  - `size`
  - `horizon`
  - `vertical`
  - `backgroundColor`
  - `borderColor`
  - `borderStyle`
  - `borderWidth`
  - `borderRadius`
  - `rotate`
  - `arrowBegin`
  - `arrowEnd`
  - `arrowStyle`
  - `arrowWidth`
  - `endPointSize`
- `layoutOptions` = shape 在 item-setting 里的 click/hover interaction 子集：
  - click path：`clickHandler` / `redirect` / `customJS` / `scrollControl` / `controlContainerId` / `controlContainerTab`
  - hover path：`actionType` / `hoverHandler` / `hoverAction`

这里要继续坚持两个边界：

- shape 的交互字段仍然**不是** `layout.options.events`；button 之外不要写 `events[]`
- `element shape` 旧有的 standalone `options` surface 仍存在，但在 `dashboard plan` 里优先使用拆分后的 `shapeOptions + layoutOptions`

## Container / Tab 的当前边界

container 内的嵌套控件目前重点支持：

- `button`
- `chart`
- `text`
- `filter`
- `shape`

如果在 tab 里继续放更复杂的嵌套结构，不要默认它已经被完整支持；当前实现对未覆盖类型会走 warning 分支。

## 最小占位模板

当用户没有提供真实 schema 时，优先给这种骨架，而不是填入具体业务字段：

```yaml
- type: chart
  chartType: <chartType>
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

- type: filter
  filterType: <filterType>
  filterField: "{<filter_field>}"
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  layout:
    x: 0
    y: 4
    w: 3
    h: 1
```

`layout` 常用的是 `x`、`y`、`w`、`h`、`zIndex`，不要随手改写成 `width`、`height`。

`zIndex` 是有意叠放时最重要的确定性字段：

- dashboard 布局**可以**存在重叠，不要求所有控件都像传统 BI 网格那样彼此分开
- 当你要做 KPI 卡片 + 背景图、图标角标、浮层文本时，不要把重叠当成异常
- 需要稳定层级时显式写 `zIndex`；不要依赖“谁先创建谁在上面”的偶然顺序

一个典型的叠放式卡片可以拆成三层：

```yaml
- type: image
  imageUrl: <background_image_url>
  layout:
    x: 0
    y: 0
    w: 4
    h: 3
    zIndex: 100

- type: chart
  chartType: Kpi
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  axes:
    - kind: formula
      op: "{<metric_field>}"
      name: metric
  layout:
    x: 0
    y: 0
    w: 4
    h: 3
    zIndex: 110

- type: text
  textContent: "同比 +12%"
  layout:
    x: 2
    y: 0
    w: 2
    h: 1
    zIndex: 120
```

如果用户要的是常规分析页，默认仍先给不重叠 layout。只有当需求明确是“卡片感”“背景层”“浮层标记”“装饰性页面”时，再主动使用叠放布局。

## 推荐写法

1. 从本参考里的最小 skeleton 起步；图表轴位看 `chart-axes.md`，过滤器字段看 `filter-config.md`，运行时结构看 `dashboard-runtime.md`，不要再引用 skill 目录外的示例文件。
2. 先确认 `app_id`、`datasetId`、`dataAppId` 都是真实存在的。
3. `app_id` 是目标 dashboard 所在 app，`dataAppId` 是 source data-app；普通 dashboard create 不会替代 chart/filter 里的数据绑定。
4. 写 plan 前先跑 `hbi dataset fields --app <app_id> --dataset <dataset_id>` 和 `hbi metric list --app <app_id> --dataset <dataset_id>`；`Purpose` / `Format` / `Display Value` 列现在会帮助判断字段职责、日期/数字展示格式，以及字段是否已经配置了显示值映射。
5. 如果用户没有提供真实 schema、字段名、数据集 ID，就输出可替换占位符，例如 `<datasetId>`、`<dataAppId>`、`{<field>}`；不要编造 `100`、`17`、`{sales}`、`{month}` 这种具体值。
6. 如果用户只是说“销售仪表盘”，不要把示例里的业务字段直接当成用户真实字段；先提醒它们只是模板占位。
7. 先用最小可运行版本验证布局和数据绑定，再加样式和嵌套结构。
8. 先对新仪表盘执行一次 `apply`，稳定后再考虑 `--update` 到既有仪表盘。
9. `apply` 前先跑 `hbi dashboard plan validate --file plan.yaml --app <app_id>`。
10. 应用后立刻用 `hbi dashboard show --app <app_id> <dashboard_id>` 回查。

如果这页存在有意叠放，再额外确认：

11. `layouts` 里相关控件的 `zIndex` 顺序是否符合预期。
12. 装饰层没有遮挡真正可交互的图表 / 过滤器。

## 当前实现边界

- `DashboardPlan` 的 YAML 类型接受 `description`、`folderId`、`theme`、`grid`，但当前 `apply_plan` 真正稳定映射到创建/patch 流程的主要还是 `name`、部分 `grid` 字段和 `elements`。
- 顶层 `theme`、`folderId`、`description` 目前不要写成“已经完整映射到 dashboard runtime JSON”的强承诺；详细差异见 `dashboard-runtime.md`。
- 图表样式可写字段比当前稳定落盘范围更宽。写文档时只写已经确认会输出的字段；详细差异见 `chart-axes.md`。

## 当前未固化 / 不要假设

- 不要假设 `scaffold` 覆盖所有 chartType；当前只覆盖一组保守的安全图表。
- 不要假设 `validate` 会自动修 plan；当前只负责报错和提示。
- 不要假设所有 chart/filter family 的完整 runtime 都已经能从 YAML 直接表达。
- 不要假设 `containerTabs` 内已经支持所有顶层控件和所有嵌套层级。
- 不要假设 plan YAML 能一比一代表完整 dashboard runtime JSON。

## 更新路径的当前边界

- `--update <dashboard_id>` 是“读取现有 dashboard，再重算目标状态”的入口，不是让你在 YAML 里手写控件定位补丁。
- 当前计划文件里不要编造 `elements[].id: control1` 这种“稳定锚点”写法；当前 CLI 不会把它当成既有控件的官方定位字段。
- 如果现有控件的字段、类型、标题还没确认，不要在更新示例里再臆造 `name`、`id`、业务字段；最多给 layout skeleton，并要求先回查现有 dashboard JSON。
- 如果用户要更新现有两个控件的布局，先建议他确认当前 dashboard 的结构，再给目标状态 YAML。
- 最安全的回查方式是：`hbi dashboard show --app <app_id> <dashboard_id> --output json`。
- 如果只是改单个控件的小字段，优先考虑 `hbi element ...`，不要默认一定该走整页 plan。

## 什么时候优先用 Dashboard Plan

优先用 `dashboard plan`，而不是逐条 `element` 命令的场景：

- 一页里有多个图表 / 过滤器 / 文本 / 容器
- 需要 container tab 布局
- 需要把布局和样式版本化
- 需要重复部署同一类仪表盘模板

## 什么时候不要直接用 Dashboard Plan

以下情况先停下来：

- 数据集 ID 还没确认
- 图表字段 / 轴语义还没理清
- 需要业务指标中心的分析看板资源，其实应该走 `kanban`
- 主题域指标 ID 还没从 `hbi subject list-metrics` 确认
- 只改一个现有图表的小字段，用 `element` patch 更直接

## 禁止事项

- 不要混用 `snake_case` 和 `camelCase`
- 不要假设 container tab 内支持所有顶层控件类型
- 不要把模板示例里的 `datasetId`、`dataAppId`、字段名当成真实环境值直接发给用户
- 不要编造 `elements[].id`、`control1` 之类的更新锚点
- 不要把主题域业务指标当成普通 dataset field / formula 来写；主题域 chart 必须用 `measureSubjectId` + `kind: measure`
- 不要在未确认 `--update` 目标 dashboard 的情况下直接覆盖生产布局
