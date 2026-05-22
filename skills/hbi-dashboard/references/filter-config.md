# Filter Config Reference

在以下场景继续读取本参考：

- 需要写 `filterType`，但不确定它和 `filterUse` / `filterMethod` 的关系
- 需要解释过滤器运行时 JSON，而不是只写 plan 最小模板
- 需要说明树形、日期、参数、数据集过滤器的边界

## 心智模型

- `filterType` 是控件大类，例如 `filter`、`datePicker`、`param`
- `filterUse` 是交互方式，例如 `radio`、`checkbox`、`date-range`
- `filterMethod` 是具体 UI 呈现，例如 `select`、`calendar`、`tab`
- `enableDisplayValue` 只是打开“显示映射值而不是原始值”的开关；真正的映射目标仍来自数据集字段自己的 `displayConfig`
- `dashboard plan` 现在已经能表达一组常用过滤器字段，但还不是前端完整 filter runtime 的等价镜像

## 运行时高频字段

| 字段 | 含义 | 说明 |
|---|---|---|
| `filterType` | 控件类别 | 如 `filter`、`datePicker`、`param` |
| `filterUse` | 过滤器行为 | 如 `radio`、`checkbox`、`date-range` |
| `filterMethod` | UI 呈现方式 | 如 `select`、`checkboxGroup`、`calendar` |
| `filterField` | 绑定字段 | plan 里通常写 `"{<field>}"` |
| `enableDisplayValue` | 是否显示 display value | 常见于 `id -> name` 这类字段 |
| `treeType` | 树形过滤器行为 | 常见值如 `strict`、`loose` |
| `filterOptions` | 常用 options 子集 | 例如 `placeholder`、`mobileOptions`、样式类字段 |
| `filterMultiple` | 是否允许多值 | 只是一个维度，不是总开关 |
| `datasetId` / `dataAppId` | 数据绑定 | 需要和图表使用的数据集保持一致；`dataAppId` 指承载该数据集的 source data-app，不是 dashboard 的 `appId` |

## CLI 当前安全默认组合

这些组合适合作为文档和 scaffold 的“安全默认值”：

| filterUse | 默认 filterType | 默认 filterMethod |
|---|---|---|
| `checkbox` | `filter` | `checkboxGroup` |
| `radio` | `filter` | `radioGroup` |
| `range` | `filter` | `rangeSlider` |
| `slider-step` | `param` | `slider` |
| `date-range-step` | `multipleDateParam` | `paramDateRange` |
| `param-input` | `param` | `input` |
| `param-input-number` | `param` | `inputNumber` |
| `param-calendar` | `param` | `calendar` |
| `expression` | `filter` | `expressionDefault` |
| `date-range` | `datePicker` | `rangeCalendar` |
| `date-period` | `datePicker` | `tab` |
| `date-calendar` | `datePicker` | `calendar` |

## 已固化的安全场景

- 列表型过滤器：`checkbox` / `radio` / `searchInput`
- 日期过滤器：`date-range` / `date-period` / `date-calendar`
- 参数型过滤器：`param-input` / `param-input-number` / `param-calendar` / `date-range-step`
- 树形过滤器的基础形态：`filterTree` / `paramTree` + `treeType`
- 常用样式 runtime：`filterOptions.titleStyle`、`filterOptions.style.alignment`、`filterOptions.style.itemStyle`、`filterOptions.style.itemActiveStyle`
- 移动端差异配置：`filterOptions.mobileOptions`（只有在确实不同于桌面端时才值得显式写）

## 树形过滤器快速判断

- “动态树”不是新的 `filterType`
- 普通维度筛选树默认先按 `filterTree` 理解
- 只有明确是参数控件 / app param 场景时，才改成 `paramTree`
- 当前没有稳定 runtime 证据时，普通维度树先给 `treeType: loose` 的最小骨架；只有明确是 `paramTree` 且 app param 级联关系已知时，才考虑 `fieldSiblings`，不要顺手编造 `hierarchy`、`chain`

## Plan 可以安全表达的最小模板

```yaml
- type: filter
  filterType: filter
  filterField: "{<filter_field>}"
  enableDisplayValue: true
  filterUse: radio
  filterMethod: select
  filterOptions:
    placeholder: "<placeholder>"
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  layout:
    x: 0
    y: 0
    w: 3
    h: 1
```

如果用户没有给出真实字段，不要补成 `{region}`、`{month}` 这类具体值。

### 日期范围过滤器

```yaml
- type: filter
  filterType: datePicker
  filterField: "{<date_field>}"
  filterUse: date-range
  filterMethod: rangeCalendar
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  layout:
    x: 0
    y: 0
    w: 3
    h: 1
```

### 树形过滤器

```yaml
- type: filter
  filterType: filterTree
  filterField: "{<dimension_field>}"
  filterMultiple: true
  filterUse: checkbox
  filterMethod: select
  treeType: strict
  datasetId: <datasetId>
  dataAppId: <dataAppId>
  layout:
    x: 0
    y: 0
    w: 3
    h: 1
```

## 当前已固化

- plan 稳定支持的重点是：`filterType`、`filterField`、`enableDisplayValue`、`filterMultiple`、`filterUse`、`filterMethod`、`treeType`、`filterOptions`、`datasetId`、`dataAppId`、`layout`
- `filterOptions.style.flexWrap` 现在按前端 runtime 真实值透传，常见写法是 `"nowrap"` / `"wrap"`，不要再把它当成布尔值
- `enableDisplayValue` 只是在 filter field 上打开显示值映射；如果数据集字段自身没有配置映射关系，单独写这个开关也不会凭空出现显示值
- `filterMultiple` 不是前端过滤器能力的总开关。日期、参数、树形、多值输入都各有自己的一组字段
- 明确的 `paramTree` / app param 级联场景现在可以稳定 round-trip `fieldSiblings`；但不要把这推广成一般 dataset filter / linkage filter runtime 都已固化
- 当前真正可对外承诺的 filter linkage slice 仍然只到 `paramTree + fieldSiblings`；`associationChart`（datePicker 图表绑定）、`byDashboard`、`chain` 等更深 linkage / global-style 结构还不是稳定 CLI authoring surface

## 当前未固化 / 不要假设

- 更复杂的 linkage / global-style runtime 字段，例如 `associationChart`、`hierarchy`、`byDashboard`、`chain`、`stylesAtDashboard`，以及超出 `paramTree + fieldSiblings` 最小闭环的树级联结构
- 每一种 `filterOptions` 子字段和嵌套 style 都已经文档化
- 所有 dataset filter / linkage filter / 树形级联行为都能直接盲写
- 复杂 operator 矩阵、默认值联动、发布态展示细节都已完全固化

## 文档写法建议

- 只给 plan 模板时，先写最小子集，不要把运行时所有字段都塞进 YAML
- 需要说明“显示样式”时，明确区分 `filterType` 和 `filterMethod`：前者是控件大类，后者是具体 UI 呈现
- 需要树形过滤器时，先确认是 `filterTree` 还是 `paramTree`，再确认 `treeType` 是 `strict` 还是 `loose`
- 需要日期参数时，不要把 `datePicker`、`multipleDateParam`、`param` 混成同一个概念
- 如果字段带有 display value，优先在模板里把 `enableDisplayValue: true` 写明，而不是假设运行时会自动推断

## 禁止事项

- 不要把 `filterType` 当成 UI 样式名
- 不要把 `filterUse` / `filterMethod` / `filterType` 混写成一个字段
- 不要因为 plan 里有 `filterMultiple`，就假设运行时过滤器只有“单选/多选”这一个维度
- 不要在文档没明确列出的情况下编造 `options` 子字段
