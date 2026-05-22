# Dashboard Runtime Reference

在以下场景继续读取本参考：

- 需要解释 `hbi dashboard show --output json` 的结构
- 需要说明 `layouts`、`chartMap`、`filterMap`、`containerMap`、`tabMap` 的关系
- 需要判断 `dashboard plan` 的 YAML 子集和前端 runtime JSON 之间还差哪些字段

## 运行时对象地图

`dashboard show --output json` 的核心是 `options`。可以把它理解成“元素对象 + 布局对象 + 设备配置”的组合。

| 字段 | 含义 |
|---|---|
| `charts` | 图表 ID 列表 |
| `chartMap` | 图表对象表，key 通常是 chart id |
| `filters` | 过滤器 UID 列表 |
| `filterMap` | 过滤器对象表，key 通常是 filter uid |
| `containers` | 容器 ID 列表 |
| `containerMap` | 容器对象表 |
| `tabMap` | 容器 tab 对象表 |
| `layouts` | 默认布局表，key 是 layout item id |
| `mobileLayouts` | 移动端布局表 |
| `pxLayouts` / `pxMobileLayouts` | 固定尺寸布局表 |
| `config` | dashboard 主题、网格、设备、模式配置 |
| `page` | infographic/page 尺寸与背景配置 |

## Layout item

前端 layout 结构比 plan 里的 `layout` 更丰富。运行时高频字段通常包括：

- `i`
- `x`
- `y`
- `w`
- `h`
- `type`
- `zIndex`
- `src`（image）
- `text`（text / rich text）
- `options.style` / `options.events`（button 等控件）
- `options` / `events` / `redirect` / `stylesAtDashboard`（高级场景）

对 CLI/Agent 来说，最重要的是先保证：

- `i` 能稳定关联到元素对象
- `x / y / w / h` 正常
- `type` 与真实元素类型一致
- 图表/图片等额外信息不要丢

当前 button 的稳定 runtime 落点也在 layout item 上，而不是单独的 object map：

- `type = button`
- `i` 通常是前端风格 key，如 `1button`、`2button7`
- `title` 在 layout item root
- `options.style` 承载按钮样式
- `options.events` 承载按钮事件数组

### 叠放 / 覆盖不是异常

`layouts` 里的控件区域可以故意重叠；这不一定是错误。在仪表盘被当成页面构建面使用时，下面这些都属于合理运行时形态：

- KPI 卡片上叠加图标或角标
- 图片做背景层，上面再压文本或 KPI
- 图表角落放状态标签、说明文字、浮层数字

这时最关键的是 `zIndex`：

- `zIndex` 更小：更靠后，适合作为背景层 / 装饰层
- `zIndex` 更大：更靠前，适合作为主信息层 / 可交互层

不要假设所有 `x / y / w / h` 区域都必须互斥；但也不要把“偶然重叠”当成稳定合同。只要是有意叠放，就应该显式回查对应 layout item 的 `zIndex`。

## Container / Tab

运行时 container 由两部分组成：

1. `containerMap[containerId]`
2. `tabMap[tabId]`

高频字段：

- container：`id`、`title`、`type`、`tabs`、`activeTabIndex`、`options.tabsOptions`、`options.style`、`options.mobileOptions`、`options.config`
- tab：`id`、`title`、`parentId`、`options.layouts`、`options.charts`、`options.filters`、`options.config`

`tabsOptions` 常见字段：

- `mode`
- `use`
- `hideTabs`
- `pagingAuto`
- `pagingGesture`
- `pagingTiming`
- `pagingAnime`
- `pagingAlignment`
- `margin`
- `alignment`
- `position`
- `paddingLeft` / `paddingTop` / `paddingRight` / `paddingBottom`

当前 CLI/plan 侧已经有一层稳定映射：

- `elements[].containerOptions.activeTabIndex -> container.activeTabIndex`
- `elements[].containerOptions.tabsOptions -> container.options.tabsOptions`
- `elements[].containerOptions.style -> container.options.style`
- `elements[].containerOptions.mobileOptions -> container.options.mobileOptions`
- `elements[].containerOptions.config -> container.options.config`（并同步保留到 container root `config`）
- `elements[].containerTabs[].config -> tab.options.config`
- tab / container 下的 `charts` / `filters` 列表由 CLI 根据嵌套元素自动补齐

## Dashboard config

前端 `config` 比当前 plan 的顶层字段更完整，常见包括：

- `showGrid`
- `rulers`
- `background`
- `mode`
- `pc`
- `mobile`
- `filterArea`
- 固定尺寸相关的 `width` / `height` / `scaleMode` / `scaleAlign`

当前 `dashboard plan` 顶层已经能稳定表达第一层 shell / device 安全子集：

- `grid.columns`
- `grid.margin`
- `pc.w` / `pc.h` / `pc.gap` / `pc.scale` / `pc.scaleMode` / `pc.theme`
- `mobile.mode` / `mobile.w` / `mobile.h` / `mobile.gap` / `mobile.scale` / `mobile.scaleMode` / `mobile.theme`
- `theme.backgroundColor`
- `theme.backgroundImage` / `theme.backgroundSize` / `theme.backgroundRepeat` / `theme.backgroundPositionX` / `theme.backgroundPositionY`

其中：

- `grid.columns` / `grid.margin` 仍然是 `config.pc.w` / `config.pc.gap` 的默认来源
- 如果 plan 里同时写了 `pc.w` / `pc.gap`，显式 `pc.*` 会覆盖 `grid.*`
- 这些字段会在 `dashboard plan apply` 里 merge 到现有 `options.config.pc` / `options.config.mobile`，不是整块覆盖
- `options.page` 仍可能出现在旧仪表盘或兼容返回里，但它属于 `InfoGraphic / 高级仪表盘` 遗留分支，不再是稳定 CLI authoring 合同
- fixed-size 现在已经有最小稳定 authoring slice：`dashboard.sizeMode: fixed` + `pc/mobile.width` / `height`，以及可选 `scaleMode` / `scaleAlign`
- 当 plan 进入 fixed-size mode 时，CLI 会从逻辑 `layouts` / `mobileLayouts` 自动生成 runtime `pxLayouts` / `pxMobileLayouts`
- 但 `pxLayouts` / `pxMobileLayouts` 仍然是 runtime 派生布局表，不是建议手写的 plan surface；当前直接手写这两个分支依然会被拒绝

这仍然不意味着 plan YAML 已经成为前端 runtime JSON 的一比一导出格式。

## 当前 CLI 最值得回查的后置条件

无论是 `create`、`update` 还是 `plan apply`，回查时都优先确认这些点：

1. `options.type`
2. `options.config.mode`
3. `options.config.pc`
4. `options.config.pc.gap`（网格布局场景尤其关键）
5. `layouts` 是否包含所有元素
6. `chartMap` / `filterMap` / `containerMap` / `tabMap` 是否和布局一致
7. 如果页面存在叠放，相关 layout item 的 `zIndex` 顺序是否符合预期
8. 如果图表依赖展示格式/显示值，检查 `options.axes[*].formatter`、`usingDatasetFormatter`、`enableDisplayValue` 是否仍在

如果这里已经缺字段，不要先怪 GUI；先把 runtime JSON 对齐问题排掉。

关于 formatter 相关回查，再补一条经验规则：

- `kind: field` 轴如果走数据层继承，runtime 里可能只保留 `usingDatasetFormatter: true`，把最终 leaf formatter 留给前端 `getAxisFormatter()` 在展示时解析
- `kind: formula` 轴如果需要稳定 number/date 格式，runtime 里更应该直接看到显式 `formatter`
- table-family runtime 里出现的 `typedFormatter` / `formatterOrigin` 更像深层 runtime / 兼容字段；它们不应替代当前 plan authoring 的 `formatter` / `usingDatasetFormatter`

## 当前 CLI 表达边界

- plan / create / update 现在已经能稳定处理常见 analytic dashboard 的图表、过滤器、文本、图片和 container/tab 基本布局
- button 现在也有稳定 authoring/runtime 路径；`layout.options.events` 当前应理解为 button-only 的稳定合同：前端 editor 写入和 runtime 执行都以 button 为主，不要把它外推成任意 layout item 的通用事件 surface
- 第一层顶层 device 配置已经有安全 authoring 路径：`config.pc`、`config.mobile`
- 已有若干高级字段的窄稳定 slice：chart 顶层 `options.redirect`、text / image 的 `layoutOptions.{titleStyle,stylesAtDashboard,clickHandler,redirect,customJS,scrollControl,controlContainerId,controlContainerTab}`、shape 的 `shapeOptions + layoutOptions.{clickHandler,redirect,customJS,scrollControl,controlContainer*,actionType,hoverHandler,hoverAction}`，以及 table-family axis 的 `redirectType`
- fixed-size 现在已经有安全主干，但顶层 `description`、`folderId`、`grid.rowHeight`、`theme.accentColor`、以及 fixed-size 更深 runtime 选项还不适合写成“已经完整映射前端 runtime”的强承诺
- `dashboard show` 返回的是运行时对象图；它天然比计划文件更细，也更适合做回查和调试
- 如果某个字段只存在于前端完整 runtime JSON，而 plan 里没有对应表达方式，就不要编造成 YAML 已支持

## 当前未固化 / 不要假设

- 不要假设完整 `pxLayouts` / `pxMobileLayouts` / fixed-size 深层 mode 分支都已能从 plan 一比一映射到 runtime。
- 不要假设 `description`、`folderId`、`grid.rowHeight`、`theme.accentColor`、`unlimitedWidth` / `unlimitedHeight` 等顶层或 mode 深层字段都已经稳定落盘。
- 不要假设 layout 上更深的通用 `events`、以及超出 `text` / `image` / `shape` 当前稳定子集的通用 `stylesAtDashboard` / redirect/event 覆盖都已经有稳定 authoring 入口；当前 `layout.options.events` 仍是 button-only，而 shape 的 hover 也只在当前 `layoutOptions.{actionType,hoverHandler,hoverAction}` 这条窄 slice 上有明确支持。
- 不要假设只看 plan YAML 就足够定位所有 GUI 异常；runtime 回查仍然是必要步骤。

## 推荐排查顺序

1. 先用 `hbi dashboard show --app <app_id> <dashboard_id> --output json` 看 `options`
2. 先看 `config` 和 `layouts` 是否完整，再看 `chartMap` / `filterMap` / `containerMap`
3. 如果页面报布局或 hydration 错误，优先确认 `options.config.pc` 和 `options.config.pc.gap`
4. 如果是 container/tab 问题，先查 `containerMap` 和 `tabMap` 的引用关系
5. 如果 runtime JSON 看起来完整，再去看 GUI 或前端交互层

## 禁止事项

- 不要把 plan YAML 当成 runtime JSON 的完整镜像
- 不要只看 `layouts`，忽略对象表是否同步存在
- 不要在没有回查 `dashboard show` 的情况下，直接把 GUI 报错归因为前端问题
- 不要编造 `elements[].id` 这类“稳定锚点”来假设 update 会命中现有控件
