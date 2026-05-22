---
name: hbi-dashboard-taste
description: "仪表盘页面构图 / 品味技能。凡是用户说“把 dashboard 做得更有设计感 / 页面感 / 品牌感 / 层次感”、想做首页感总览页、运营海报感、驾驶舱、移动摘要页、背景图+KPI+文字叠放、想先拿设计 brief 再落 dashboard plan YAML skeleton，或明确问题在页面构图而不是字段/图表语义时，都应该使用本技能。即使用户没有明确说“taste”或“设计 brief”，只要核心诉求是页面观感、层级、节奏、anti-slop，而不是数据语义，也应主动使用。本技能不替代 hbi-dashboard 的数据/图表 authoring contract。"
metadata:
  requires:
    bins: ["hbi"]
---

# HBI Dashboard Taste

> 前置：先读 `hbi-core` 和 `hbi-dashboard`。
>
> 本技能是 **page-composition layer**，不是数据建模或图表语义技能。它负责把已经基本明确的数据语义，组织成更有页面感、更有层次、更少“AI 模板味”的 Everest 仪表盘。

## 角色边界

负责：

- 页面层级
- 布局节奏
- 模块主次
- 页面 archetype 选择
- 品牌/气质翻译
- 背景、角标、浮层文字、卡片组合、叠放策略
- 桌面/移动端的阅读顺序

不负责：

- 发明字段、指标、`datasetId`、`dataAppId`
- 擅自改 chart family
- 绕过 `hbi-dashboard` 的安全 authoring 面
- 把 dashboard plan 当成 HTML/CSS 去写

默认输出固定为两部分：

1. **设计 brief**
2. **dashboard plan YAML skeleton**

如果用户只想先讨论方向，可以只给 brief；如果上下文或数据语义还不够，不要强行给假装可执行的 YAML。

## 上下文收集协议

没有设计上下文，就不会有真正有判断力的页面构图。不要从字段名、现有 dashboard JSON、代码结构里臆测“这页应该看起来像什么”。那些信息只能告诉你现在有什么，不会告诉你**谁在看、为什么看、希望它有什么气质**。

至少确认这些上下文：

1. **Audience**：谁在看？高管、运营、销售、分析师、一线人员，还是嵌入式终端用户？
2. **Use context**：在什么场景下看？周会、监控、展厅、首页入口、门店手机快读、嵌入首页？
3. **Brand / tone**：希望页面是什么气质？克制、冷静、厚重、精致、海报感、驾驶舱感、编辑感、工具感？
4. **Anti-reference**：明确不要像什么？不要太像营销页？不要太像活动海报？不要太像 bland BI 模板？
5. **Device priority**：桌面优先、移动优先，还是双端都要考虑？
6. **Layering intent**：是否明确需要背景图、角标、浮层文字、叠放式 hero？
7. **Interaction priority**：哪些控件必须保持强交互且不能被装饰层遮挡？

收集顺序：

1. **先用当前对话里已经明确给出的上下文**，不要重复问已经清楚的事。
2. **如果只是部分清楚**，补 2-4 个最关键的问题，不要把用户拖进冗长问卷。
3. **如果用户只说“做得更有设计感一点”**，先问，不要直接开始写 YAML。
4. **如果用户只想聊方向**，先停在 brief，不要勉强输出可执行 skeleton。

## 不要越权到数据语义层

如果下面这些还没明确，先转回 `hbi-dashboard`：

- dataset fields / atomic metrics 还没确认
- 图表 family (`Line` / `Bar` / `Table` / `KPI` / `Geo2D` ...) 还没定
- 还在讨论“这个业务问题该用什么图表达”
- Geo / filter / runtime 前置条件是否成立还不清楚

这个技能的职责是：

- **图表达已经基本确定** → 把页面做得更好
- **图表达还没确定** → 先回 `hbi-dashboard`

如果用户想同时解决“图该怎么选”和“页面怎么做得更好看”，先让 `hbi-dashboard` 把语义骨架定下来，再回来做 taste layer。

## 先定方向，再出骨架

先按这几步走：

1. **提炼 3 个具体气质词**  
   例如“稳重 / 冷静 / 精准”“编辑感 / 品牌化 / 克制”“密集 / 快速 / 告警导向”。  
   不要停在“现代”“高级”“好看”这类空词上。

2. **选一个页面 archetype**  
   先决定这页是什么，不要一开始就堆控件。

3. **确定一个明确的视觉记忆点**  
   是 hero KPI？是强对比的结构？是品牌背景 + 核心数字？是 dense cockpit 的异常优先级？  
   每页只需要一个主招，不要同时追 4 种风格。

4. **从使用场景推导 theme / density / hierarchy**  
   深夜盯盘的运营屏和早上手机快读的门店首页，默认主题和节奏不应该一样。  
   关键是**intentionality, not intensity**：不是越花越好，而是方向清晰。

5. **最后才写 YAML skeleton**  
   不要先给 YAML 再补解释。

## 页面 archetypes

| Archetype | 适用场景 | 默认策略 |
| --- | --- | --- |
| Conventional analytic grid | 常规经营分析页、周报页 | 不重叠，分区清晰，KPI 行 + 主图 + 辅助表 |
| Executive overview | 高管总览、汇报首页 | 强层级，大信息块，少而重的核心信息 |
| Editorial / poster page | 海报感首页、品牌化封面页 | 允许 image + KPI + text 叠放，强调视觉焦点 |
| Dense operations cockpit | 高频监控、值班盯盘 | 高密度、异常优先、少装饰、节奏紧 |
| Mobile summary stack | 手机快读、门店首页摘要 | 垂直堆叠、短信息、高对比、少横向并排 |

默认使用 **Conventional analytic grid**。只有当用户明确要“首页感 / 海报感 / 背景图 / 角标 / 浮层文字 / 品牌化总览页”时，再切到 layered archetype。

## 设计 heuristics

### 1. 用层级，而不是堆卡片

优先通过这些方式制造层级：

- 模块尺寸差异
- 布局位置差异
- 信息密度差异
- 留白与分组
- 主信息层 / 装饰层 / 说明层的关系

不要默认：

- 所有内容都塞进同尺寸卡片
- “顶部 3 张 KPI + 下方 2 张图表”就算设计完成
- 所有页面都靠一排排白卡片拼出来

### 2. 用节奏，而不是平均分布

把 spacing / rhythm 原则落到 dashboard 语言里：

- 紧密分组的模块应该明显更近
- 主次分区之间应该留出更大的呼吸空间
- 对称不是默认值；如果要做得更有页面感，允许有意的不完全对称
- 但所有打破网格的动作都必须有理由，不能只是“看起来更设计”

对 Everest 而言，这通常意味着：

- 同页块的 `w/h` 不要全部一样
- 主阅读区、辅助区、工具区要有清晰切分
- 容器/卡片只在真正需要分组时使用，不要一层包一层

### 3. Theme 要从场景推导，不要用默认值

不要默认“浅色更安全”，也不要默认“深色更高级”。

更合理的推导方式：

- 夜间监控 / 值班 / 暗环境大屏 → 更接近低眩光深底 / cockpit
- 早会汇报 / 手机首页快读 / 品牌化总览 → 更接近明亮克制 / 中性色底 / 高对比文字
- 如果用户明确给了品牌/空间氛围，以用户上下文为准

如果你建议主题或背景方向，要顺手解释**为什么**它适合这个场景。

### 3.1 Theme direction != runtime theme contract

把“主题方向”说清楚，和把“runtime theme 值”写对，是两回事。

- 在 **brief** 里，可以说“低眩光深底”“明亮克制”“中性浅灰底”“品牌化低饱和背景”。
- 在 **YAML skeleton** 里，不要把这些设计词直接写成 runtime 合同。
- 不要输出 `theme: dark`、`theme: light`、`base: dark`、`base: light` 这类没有验证过的值。
- 如果用户明确要落一个真实仪表盘主题，优先用：
  - `dashboard.theme.name: <builtin_theme_base_or_custom_theme_id>`
  - 只有在明确要区分设备端时，才分别写 `pc.theme.base` / `mobile.theme.base`
- 真实候选值不要猜，用 `hbi dashboard theme list` 查：
  - 系统内建 theme base
  - 当前 app 可见的 custom theme ID / 名称
- 背景类方向如果需要落到 plan，走 `dashboard.theme.background*` 这条 authoring 面。
- `dashboard.theme.accentColor` 目前不是稳定映射面，不要把它当成可靠的 taste 输出。

### 4. Mobile 不是缩小版 desktop

移动端默认不是把桌面三列缩成窄三列，而是：

- 重新排列阅读顺序
- 压缩文字长度
- 减少横向并排
- 让“第一眼看到什么”比“信息都还在”更重要

### 5. Layering 只能强化主次，不能掩盖问题

页面化叠放时：

- `image` 常做背景或装饰层
- `chart`（常见是 `KPI`）做主信息层
- `text` 做角标、说明、标签、补充对比
- 必须显式写 `layout.zIndex`

分层顺序通常是：

- 背景层：最低 `zIndex`
- 主信息层：中间 `zIndex`
- 标记 / 浮层文字：最高 `zIndex`
- 过滤器、按钮、主交互层：必须在装饰层之上

如果 layering 只是为了把一页做得“复杂一点”，不要这么做。

## anti-slop / 反模板规则

在 dashboard 语境里，重点避免这些“AI 味”：

- 一页全是同构 KPI 卡片，只有数字和标题不同
- 用户没要求页面感，却强行加背景图、浮层字、装饰层
- 明明是 dense monitoring 页，却做成 marketing hero
- 明明是稳妥周报页，却用叠放掩盖没有层级判断的问题
- 把装饰层压在真实交互控件上面
- 一切都居中、一切都同宽、一切都同密度

特别注意：**hero metric 模板不是默认答案**。如果用户只是要稳妥分析页，不要强行给一个“大数字 + 背景图 + 角标”的首页模板。

## 输出格式

优先用这个结构：

```md
## Design context snapshot
- Audience:
- Use context:
- Tone / personality (3 words):
- Device priority:
- Anti-reference:

## 设计 brief
- Page archetype:
- Theme rationale:
- Memorable move:
- Primary hierarchy:
- Density:
- Layering strategy:
- Controls that must stay highly interactive:
- Anti-goals:

## Recommended command order

## Dashboard plan YAML skeleton

## Post-apply review checklist
```

如果上下文不够，就把第一段改成：

```md
## Missing context
- ...

## 建议先补充的信息
- ...
```

然后停止在 brief，不要假装 skeleton 已经可执行。

## Recommended command order

常用顺序：

```bash
hbi dataset fields --app <app_id> --dataset <dataset_id>
hbi metric list --app <app_id> --dataset <dataset_id>
hbi dashboard plan scaffold --app <app_id> --dataset <dataset_id> > plan.yaml
hbi dashboard plan validate --file plan.yaml --app <app_id>
hbi dashboard plan apply --file plan.yaml --app <app_id>
hbi dashboard show <dashboard_id> --app <app_id> --output json
```

如果 taste skill 只负责 brief，不要假装 `plan scaffold` 已经能自动表达所有 taste 决策；要明确指出哪些地方需要用户手工编辑 plan。

## 输出 YAML 时的硬规则

1. 不要编造 `datasetId`、`dataAppId`、字段名、metric id。
2. 数据/图表语义如果不确定，只用占位符，或明确要求先回 `hbi-dashboard`。
3. 只能用当前已稳定的 authoring 面：`chart` / `filter` / `container` / `image` / `text`。
4. 输出的是 **dashboard plan skeleton**，不是原始 runtime payload；不要生成 `chartMap` / `textMap` / `filterMap` / `options.layouts` / `chartType` 这类持久化结构名。
5. 尽量以 `hbi dashboard plan scaffold` 的结果为底，保持 `dashboard` + `elements` 这类 plan authoring 视角，而不是直接手写落盘后的大 JSON 形状。
6. 用户没要求页面化叠放时，不要主动给一堆 `zIndex`。
7. 用户明确要页面化叠放时，不要再把页面强行拍平成普通 BI 网格。
8. 如果关键上下文或 chart semantics 不够，宁可只给 brief，也不要输出假 skeleton。
9. 不要把 brief 里的“深 / 浅 / cockpit / 品牌化”直接写成 `theme: dark|light` 这类伪 runtime 合同。
10. 如果要写真实 theme 引用，只能写已验证的 theme base / custom theme id，占位符或 discovery 命令都可以，但不要猜。

## post-apply review checklist

无论页面是平铺还是叠放，最后都要给回查建议：

```text
1. 用 dashboard show --output json 回查 options.layouts
2. 如果有 layered layout，确认相关 item 的 zIndex 顺序
3. 确认 chartMap / filterMap / containerMap / tabMap 与 layouts 一致
4. 确认交互层（filter / button / chart）没有被装饰层盖住
5. 如果是移动摘要页，再看阅读顺序是否真的符合“先主 KPI，再趋势，再辅助信息”
6. 如果 GUI 有遮挡/层级异常，先怀疑 runtime 落盘，再怀疑前端
```

## 何时停止并回退

遇到这些情况，不要硬做 taste 输出：

- 数据字段 / 原子指标都还没定
- 用户其实在问 chart semantics，不是在问页面构图
- 需求超出当前 CLI 可表达边界（例如完整网页级字体系统、复杂响应式、前端动画）

这时应明确说：

- 先用 `hbi-dashboard` 把数据/图表骨架定下来
- 或者只先产出 brief，不强行给假装可执行的 YAML
