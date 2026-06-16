---
name: hbi-dashboard
description: "仪表盘领域技能。凡是用户提到仪表盘、图表、过滤器、容器、图片、文本控件、Dashboard Plan、YAML 批量布局、页面布局，或需要在应用内创建可视化页面时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi dashboard --help"
---

# HBI Dashboard

> 前置：先读 `hbi-core`。如果还没有数据层，请先转 `hbi-data`。
>
> 把 `references/` 当成当前已固化的规则集；如果某个 chart family / filter 变体 / runtime 分支不在这些文档里，就不要臆造。
>
> 需要精确的图表、过滤器、布局、控件产品名与别名时，先读 `references/canonical-terms.md`；需要把自然语言意图翻成内部术语时，再读 `references/terminology-map.md`。
>
> 需要写 `dashboard export-data/export-file` 或 `element chart export-data/export-file` 的 `--file/--value` 载荷时，继续读 `references/export-contracts.md`。

## 概念边界

- `dashboard` = 仪表盘
- `element` = 控件
- `chart` / `filter` / `container` / `image` / `text` 都挂在 `hbi element` 下
- 业务指标中心的看板资源是 `kanban`，不要和普通仪表盘混用；但 6.2 起普通仪表盘里的 chart 可以用 `measureSubjectId` 引用主题域业务指标作图
- 图表阈值告警 / data alert 是独立资源，不属于 dashboard 布局 authoring；这类问题转 `hbi-data-alert`

## 常用命令入口

### `hbi dashboard --help`

- `list`
- `show`
- `create`
- `copy`
- `delete`
- `update`
- `export-data`
- `export-file`
- `plan`

### `hbi element --help`

- `chart`
- `filter`
- `container`
- `image`
- `text`

精确参数继续向下查看：

```bash
hbi dashboard <subcommand> --help
hbi element <kind> --help
```

## 仪表盘最小工作流

### 1. 基于应用查看仪表盘

```bash
hbi dashboard list --app <app_id>
hbi dashboard show <dashboard_id> --app <app_id>
```

`dashboard` 相关高频命令普遍要求 `--app`，不是旧文档里的 `--app-id`。

### 2. 创建仪表盘

普通分析页：

```bash
hbi dashboard create "销售总览" --app <app_id>
```

报表页：

```bash
hbi dashboard create "月报" --app <report_app_id> --dashboard-type report --data-app <data_app_id> --dataset <dataset_id>
```

`dashboard create` 先关注这些参数：

- 位置参数：仪表盘名称
- `--app`
- `--dashboard-type`
- report dashboard 额外需要 `--data-app` + `--dataset`

这里要特别分清三个概念：

- `--app` 指目标 dashboard 所在的应用（analytic app / report-app）
- `--data-app` / `dataAppId` 指承载 `datasetId` 的 source data-app，不是 dashboard 所在 app
- 当前 CLI 的 `dashboard create` 里，`--data-app` / `--dataset` 这对 query 旗标是 report shell create 的入口；但这**不是**在说只有 report-app 才能使用 data-app 数据集

这个歧义经常来自 report / analytic 的 authoring 时机不同：

- `report-app`：一个报表页面基本就是一个默认 `ComplexTable` / Excel-style 报表容器，所以 create 时就要知道它绑定哪一个 `data-app + dataset`
- `analytic` / 查询类页面：`dashboard create` 更像先建一个 dashboard shell，真正的数据绑定通常发生在后续 chart/filter/container authoring 或 `dashboard plan apply`

### 2.5 复制仪表盘到其他应用

```bash
hbi dashboard copy 44 --app <source_app_id> --target-app <target_app_id>
hbi dashboard copy 44 --app <source_app_id> --target-app <target_app_id> --name "销售总览（副本）"
```

- `--app` 是源 dashboard 所在应用
- `--target-app` 是目标应用
- 当前 `dashboard copy` 直接对齐前端 copyTo：走 backend `duplicate` 接口，并补 target app 的 `dashboardsOrder` / pagination 相关 scene 元数据，不是 `plan export/apply` 旁路

当前还有几条已经很稳定、但很容易被说错的 create 合同：

- `dashboard create --dry-run`
  - report 页会打印人类可读预告：`Would create report dashboard '<name>' in app <app_id> using data-app <data_app_id> dataset <dataset_id>`
  - 普通分析页只会打印：`Would create dashboard '<name>' in app <app_id>`
  - 这里**不会**直接打印 JSON 请求体或 patch 预览
- report create 少任一 source 参数都会在本地先失败：`Report dashboards require --data-app and --dataset.`
- 非 report create 如果硬塞 `--data-app` / `--dataset`，会在本地先失败：`--data-app and --dataset are only supported with --dashboard-type report.`

如果用户要的是 blank report dashboard shell：

- 先走 `dashboard create --dashboard-type report --data-app ... --dataset ...`
- 不要先拿 `dashboard plan scaffold` 伪造一个 report YAML
- 不要手工补一个“默认空白 ComplexTable”；report create 后端会自动 seed 默认报表图表

### 3. 更新与删除

```bash
hbi dashboard update --app <app_id> --id <dashboard_id> --title "新标题"
hbi dashboard delete <dashboard_id> --app <app_id> --force
```

`dashboard update` 当前稳定显示配置面比较窄，只围绕这些旗标：

- `--title`
- `--theme`
- `--show-grid`
- `--grid-cols`
- `--grid-rows`
- `--grid-gap`
- `--grid-scale`
- `--layout-mode`
- `--background`

如果这些一个都不传，本地会先失败：

`At least one update option must be provided (--title, --theme, --show-grid, --grid-cols, --grid-rows, --grid-gap, --grid-scale, --layout-mode, or --background)`

几个最容易写错的 runtime 落点：

- `--grid-gap 12` -> `options.config.pc.gap = 12`
- `--layout-mode overlap` -> `options.config.mode.allowOverlap = true`，`preventCollision = false`
- `--layout-mode flat` -> `allowOverlap = false`，`preventCollision = true`
- `--layout-mode collision` -> 两者都不显式打开
- `--background 42` 这类非颜色值会落到 `options.config.background.image = "42"`
- `--background #112233` / `rgba(...)` 这类颜色值会落到 `options.config.background.color`

### 4. 导出仪表盘 / 图表

```bash
hbi dashboard export-data <dashboard_id> --app <app_id> --output-file dashboard.xlsx
hbi dashboard export-file <dashboard_id> --app <app_id> --format pdf --output-file dashboard.pdf
hbi dashboard export-file <dashboard_id> --app <app_id> --value '{"FILTER_UID":["East"]}' --output-file filtered.png
hbi element chart export-data <chart_id> --dashboard <dashboard_id> --app <app_id> --output-file chart.xlsx
hbi element chart export-file <chart_id> --dashboard <dashboard_id> --app <app_id> --format png --output-file chart.png
```

- 导出文件路径统一用 `--output-file`
- `dashboard export-file/export-data` 的 `--file` / `--value` 现在支持两种形态：
  - 完整 export body（前端 `DownloadDto` 形状）
  - dashboard filter 简写 `{filterUid: selectedValue}`，CLI 会展开成 `dashboard.options.filterMap`

## Dashboard Plan

把 `dashboard plan` 当成 YAML 驱动的整页仪表盘入口，不要只把它理解成一条创建快捷命令。

它现在稳定覆盖 analytic dashboards、page dashboard shell roundtrip，以及当前已固化的 report plan subset。**如果用户要的是 blank report dashboard shell，先走 `dashboard create --dashboard-type report --data-app ... --dataset ...`，不要把 `plan scaffold` 当成 report create 的替代。** 这不是因为 report 才“能”引用 data-app 数据集，而是因为 report 页面在 create 时就要确定那张默认 ComplexTable 绑定的数据源。

report 的当前稳定 plan/export/apply 边界要直接记住：

- 顶层 `dashboard.type: report` + `dashboard.dataAppId` / `dashboard.datasetId`
- zero or more top-canvas root `filter`
- zero or one bottom-canvas `ComplexTable`
- shell-managed outer `filterBtn` 继续由 runtime seed / preserve，不把它当成自由 authoring 面

现在常用有四条入口：

```bash
hbi dashboard plan scaffold --app <app_id> --dataset <dataset_id> > plan.yaml
hbi dashboard plan scaffold --app <app_id> --dataset <dataset_id> --chart-type Line > plan.yaml
hbi dashboard plan validate --file plan.yaml --app <app_id>
hbi dashboard plan apply --file plan.yaml --app <app_id>
hbi dashboard plan apply --file plan.yaml --app <app_id> --name "覆盖标题"
hbi dashboard plan apply --file plan.yaml --app <app_id> --update <dashboard_id>
hbi dashboard plan export --app <app_id> --dashboard <dashboard_id> --output yaml > exported-plan.yaml
```

- `scaffold`：根据数据集字段和原子指标生成一个可编辑 YAML 起稿，并在注释里列出字段/指标摘要
- `validate`：对 plan 里引用的 dataset fields / atomic metrics / geo prerequisites 做前置校验，并给出修复提示
- `apply`：把 YAML 计划真正落到仪表盘 create/update 路径
- `export`：把现有 analytic / page / 当前稳定 report subset 仪表盘导回可编辑 plan；如果你已经有一张工作正常的 page/report，这是最安全的起稿方式

`dashboard plan apply` 还有两条值得直接记住的执行合同：

- `dashboard plan apply --dry-run`
  - 先做 validation
  - 然后打印人类可读的 dashboard spec 摘要（name / grid / elements）
  - **不会**直接打印 JSON patch
- 真正 apply 时，CLI 会先 diff 出 patch，再把 patch path 统一补成 `/options/...`
  - 例如不是裸 `/config/...`，而是 `/options/config/...`
  - 如果 YAML 同时改了 dashboard 名称，标题更新会额外走一次 `update_dashboard`，不是和 `options` patch 混在同一个 patch 数组里
- 如果要 author fixed-size 页面，当前稳定写法是 `dashboard.sizeMode: fixed`，再配 `dashboard.pc/mobile.width`、`height`，必要时补 `scaleMode` / `scaleAlign`；CLI 会从逻辑 `layouts` 自动生成 runtime `pxLayouts` / `pxMobileLayouts`，但仍然拒绝手写这两个 runtime 分支
- `dashboard plan export`
  - page shell 已支持稳定 roundtrip
  - report 当前只支持 seeded outer `filterBtn` + top filters + default `ComplexTable` 这一层稳定 surface；超出这层不要臆造“完整 report plan parity”

适合场景：

- 要用文件方式批量创建仪表盘与控件
- 需要把仪表盘配置纳入版本管理
- 需要重复部署布局模板

遇到以下场景，继续读取 `references/dashboard-plan.md`：

- 需要写完整 YAML 结构
- 需要处理 container / tab / 嵌套控件
- 需要理解新建与更新的差别
- 需要把 Markdown 文本、样式、筛选器、图表绑定写进同一个计划文件
- 需要给用户一个“可替换占位符”的模板，而不是臆造真实 dataset / field / element 锚点

写 plan 之前，如果用户已经确定了数据集，优先先跑：

```bash
hbi dataset fields --app <app_id> --dataset <dataset_id>
hbi metric list --app <app_id> --dataset <dataset_id> --limit 20
```

前者看可用字段、类型与地理角色，后者看原子指标；不要跳过这一步直接臆造 `axes[].op`。
`metric list` 的 JSON/YAML 输出是分页 envelope；写 plan 时从 `data` 取少量候选，从 `total` 判断是否还有更多候选，不要用 `--all` 拉全量指标。
如果是时间分组，优先写真实 HQL，例如 `day({created_at})`、`month({created_at})`、`trunc_month({created_at})`；不要把日期字段先 `substring(...)` / `date_format(...)` 成字符串再拿去分组，也不要把 `field:granularity` 这种命令级 shorthand 混进 chart / plan 表达式里。

如果要在普通 dashboard 里用主题域业务指标出图，先跑：

```bash
hbi subject list-metrics <subject_id> --limit 20 --output json
hbi element chart create --dashboard <dashboard_id> --app <app_id> kpi --measure-subject <subject_id> --subject-measure <subject_metric_id>
```

规则：

- `--subject-measure` 用的是 `subject list-metrics` 返回的 `id`，可重复；不是 `subject add-metrics` 的 `appId:datasetId:fieldName` 字符串。
- 主题域 chart 不需要 `--dataset` / `--data-app`；普通 dataset chart 仍然需要 `--dataset`。
- 更复杂的主题域维度、过滤、候选指标 payload，优先用 `element chart --file` 或 `dashboard plan`，并写 `measureSubjectId`、`candidateMeasures`、`sourceMeasureKeys`、`axes[].kind: measure`。
- 如果用户要创建业务指标中心的“分析看板”资源，而不是普通 dashboard 内的一张 chart，转 `hbi-indicator-center` / `kanban`。

遇到以下更细的配置约束时，再继续读取对应参考：

- `references/terminology-map.md`：把用户自然语言（例如“带小计的表”“地图”“动态树”）翻成 chart/filter/plan 术语
- `references/canonical-terms.md`：当前已收录的 chart/filter/layout/control/shell 术语总表与别名
- `references/chart-axes.md`：`chartType`、`axes[].name`、`formatter / usingDatasetFormatter / enableDisplayValue`、常见图表轴位组合
- `references/filter-config.md`：`filterType`、`use`、`method`、筛选器运行时字段与 plan 子集边界
- `references/dashboard-runtime.md`：`dashboard show` 返回结构、`layouts` / `chartMap` / `containerMap` / `tabMap`、PC/移动端配置边界

### 树形过滤器快速判断

- 用户说“动态树”“树筛选”“省市层级树”时，先不要发明新的 `filterType`
- 默认先按**普通树形过滤器**理解：`filterType: filterTree`
- 只有用户明确在说**应用参数 / 参数控件 / app param** 时，才切到 `paramTree`
- 当前没把复杂树 runtime 全量固化时，普通维度树先给 `treeType: loose` 的最小 skeleton；只有明确是 `paramTree` 且 app param 级联关系已知时，才考虑 `fieldSiblings`，不要顺手臆造 `hierarchy`、`chain`
- `filterOptions.style.flexWrap` 当前按前端 runtime 真实值透传，安全写法是字符串 `"nowrap"` / `"wrap"`，不要再写成布尔值 `true/false`

推荐执行顺序：

1. `hbi dataset fields --app <app_id> --dataset <dataset_id>`
2. `hbi metric list --app <app_id> --dataset <dataset_id>`
3. 如果用户说的是自然语言业务诉求，先读 `references/terminology-map.md`
4. `hbi dashboard plan scaffold ...` 或直接按 `references/dashboard-plan.md` 起草
5. 如果已经有现成页面，优先 `hbi dashboard plan export --app <app_id> --dashboard <dashboard_id> --output yaml > exported-plan.yaml`
6. `hbi dashboard plan validate --file plan.yaml --app <app_id>`
7. `hbi dashboard plan apply --file plan.yaml --app <app_id>`
8. `hbi dashboard show <dashboard_id> --app <app_id> --output json`

## 布局与叠放

不要把 dashboard 只想成“若干不重叠图表的 BI 网格”。在真实产品里，它也常被当成低代码页面构建面使用，允许做**卡片式、覆盖式、装饰层 + 主信息层**的组合。

常见可接受的叠放场景：

- KPI 卡片上叠加角标、图标、装饰图
- 用图片当背景层，上面再放文本或 KPI
- 在图表或卡片右上角放补充说明 / 状态标记

执行时遵循这几个规则：

1. 如果用户只是要常规分析页，默认仍优先用**不重叠**布局。
2. 如果用户明确要“卡片感”“角标”“背景图”“浮层文字”“封面式页面”，就把它当成**有意叠放**的页面组合，而不是强行拆成互不相交的格子。
3. 有意叠放时，优先走 `dashboard plan` 或 file-based element authoring，并显式写 `layout.zIndex`；不要依赖元素创建顺序碰运气。
4. 交互控件（过滤器、按钮、主要图表）应位于装饰层之上；不要让图片或文本遮挡真实点击区域。
5. `apply` 后用 `dashboard show --output json` 回查 `layouts.*.zIndex` 和对应元素映射，确认叠放顺序确实落盘。
6. 用户报“文字被背景盖住”“元素重叠”“点不到控件”时，先不要怪 GUI。**重叠本身不一定是 bug**；先把它当成 runtime 层级问题，优先检查 `layouts.*.zIndex`、`layouts[*].i` 与对象表映射、以及 `options.config.pc` / `options.config.pc.gap` 是否按预期落盘。

## 元素管理建议

因为 `element` 下还有二级命令，使用本技能时遵循下面顺序：

```bash
hbi element --help
hbi element chart --help
hbi element filter --help
hbi element container --help
hbi element image --help
hbi element text --help
```

- 更新现有图表时，优先先跑 `hbi element chart show <chart_id> --dashboard <dashboard_id> --app <app_id> --as-spec > chart.yaml`，编辑后再 `hbi element chart update <chart_id> --dashboard <dashboard_id> --app <app_id> --file chart.yaml`；不要把 `chart create` 的内联 flags 直接脑补到 `chart update`。

## 实战建议

1. 先确认应用 ID。
2. 再确认数据集/数据模型是否已经可用，并优先用 `dataset fields` / `metric list --limit 20` 看清字段的 `Purpose`、`Format`、`Display Value`；如果用户问的是 formatter JSON，记住数据层是 `config.formatter.<type>` typed map，而图表轴层 `axes[].formatter` 只吃内层 flat leaf。
3. 如果要从零起草整页 YAML，先用 `dashboard plan scaffold` 生成一个前端安全的骨架，再做针对性编辑。
4. apply 前优先先跑 `dashboard plan validate`，把字段名、原子指标、Geo / Geo2D 地理角色前置条件、display value 这类问题提前暴露出来。
5. 如果是复杂布局，优先走 `dashboard plan apply`，不要手工反复点式拼装。
6. 如果用户没有给出真实 `datasetId`、`dataAppId`、字段名，就输出占位符模板，不要编造 `100`、`17`、`{sales}` 这类具体值。
7. 不要把 `--app` / dashboard app id 和 `dataAppId` 混用：前者是目标 dashboard 所在 app，后者是承载数据集的 source data-app；analytic / page-like dashboard 也可以在 chart/filter 绑定里显式引用 data-app 数据集，和 report 并不冲突。

## 当前未固化 / 不要假设

- 不要假设未在 `references/chart-axes.md` 里给出安全轴位的冷门 chartType 已经有稳定 authoring 合同。
- 不要假设完整 table HQL / cell formula / growth calculation 模型已经产品化到当前 CLI surface。
- 不要假设完整 filter linkage / global-style runtime（例如 `associationChart`、`chain`、`byDashboard`，以及超出 `paramTree + fieldSiblings` 最小闭环的树级联结构）都已经有稳定 authoring 入口。
- 不要假设 button 之外的通用 `layout.options.events` 都已经稳定。当前稳定边界要明确分开记：
  - button 的 `layout.options.events`：这是当前唯一稳定的 `events[]` authoring/runtime 合同；前端 item-setting 挂载和 runtime 执行链也都是 button-only
  - chart 顶层 `clickHandler: redirect` + `redirect`
  - text / image 的 `layoutOptions.{titleStyle,stylesAtDashboard,clickHandler,redirect,customJS,scrollControl,controlContainerId,controlContainerTab}`：它们走的是另一套非 button 交互字段，不是 `layout.options.events`
  - shape：现在也已经接进 `dashboard plan` 的共享 typed surface，但要按两层理解：
    - `shapeOptions` = 形状外观/runtime 子集（`backgroundColor`、`border*`、`rotate`、`arrow*` 等）
    - `layoutOptions` = click/hover 交互子集（`clickHandler`、`redirect`、`customJS`、`scrollControl`、`controlContainer*`、`actionType`、`hoverHandler`、`hoverAction`）
  也就是说，当前**不是**“任意 layout item 都有通用跳转/事件合同”；更深的通用 layout `events` 和其它控件未审计的 redirect/event surface 仍不要臆造。
- 不要假设完整 dashboard page / mobile / fixed-size 深层 runtime（例如 `unlimitedWidth` / `unlimitedHeight`、手写 `pxLayouts` / `pxMobileLayouts`）都已经有安全 plan surface。
- 自动修复缺失的 metric、geo role 或其他前置条件；`validate` 当前只负责提前报错和提示
- 不要假设 `dashboard.page` 仍能继续作为稳定 authoring 入口；它现在只是 legacy `options.page` / InfoGraphic 兼容块，当前 CLI authoring 不再应用它。要表达当前 shell / device 设置，改写到 `pc`、`mobile`、`theme.background*`

## 与 `kanban` 的边界

- 普通图表型分析页面：用 `dashboard` + `element`
- 普通 dashboard 里使用主题域业务指标出图：仍然用 `dashboard` / `element chart`，数据源写 `measureSubjectId`
- 业务指标中心的分析看板资源：转 `hbi-indicator-center`，由它使用 `kanban`

如果用户强调“指标中心分析看板 / kanban / 指标上墙到看板”，优先切到 `hbi-indicator-center`；如果他说的是“在普通仪表盘里用主题域指标作图”，留在 `hbi-dashboard`。

## 禁止事项

- 不要把 `dashboard_id` 和元素 ID 混用。
- 不要在没有数据层的情况下直接假设图表可建。
- 不要编造 `datasetId`、`dataAppId`、字段名，或 `elements[].id` 这类定位字段。
- 不要继续沿用旧技能里 `--app-id` 的写法。
