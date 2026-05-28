---
name: hbi-workflow
description: "跨领域工作流技能。凡是任务同时涉及多个 Everest 资源域，例如从数据连接一路做到应用、仪表盘、权限、租户、主题域、分析看板、调度或笔记时，都应该使用本技能来编排其他 Everest 技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi --help"
---

# HBI Workflow

> 本技能不替代其他领域技能，而是负责串联它们。

## 何时使用

当任务满足以下任一条件时，使用本技能：

- 需要跨多个命令域完成完整业务链路
- 需要先搜索或定位资源，再逐步修改资源
- 需要把数据层、应用层、权限层、组织层串起来
- 需要给其他 Agent 设计“先后顺序”和“验证点”

## 基本编排原则

1. 先定位资源，再修改资源。
2. 每进入下一阶段之前，都重新确认上一步产出的 ID。
3. 变更类命令优先查看 `--help`，必要时加 `--dry-run`。
4. 自动化串联时优先 `--output json`。
5. 某一步失败时，不要默认回滚前一步，除非用户明确要求。
6. 本技能负责顺序、验证点和切换边界；不要在跨域回答里臆造子阶段的细参数。

## 输出要求

- 用户要“整条链路”时，优先输出阶段顺序、每阶段的稳定入口命令、以及阶段间验证点。
- 不要在本技能里展开 `connection create`、`element chart` 这类还没切到子技能就开始猜的详细参数。
- 不要在本技能里猜 `dataapp-replace --replace ...` 的载荷格式；先停在 `--list` 和 `--help`。
- 如果某个阶段需要精确参数，明确切到对应技能，或提示用户先执行 `hbi <命令族> <子命令> --help`。

## 跨域执行时的 preflight

- 执行型请求默认继续，不要求用户再补一句“去执行”。
- 在第一次写操作前，先给出阶段顺序、命令树选择、预检命令、验证点；然后直接进入第一阶段。
- 这是工作流层的 **speak-then-act**，不是 ask-then-wait。

## 风险升级与收口

- 某阶段如果需要退回相邻 generic `update`、或只能靠未经验证的 raw payload，先停在该阶段解释风险，不要跨命令树“借道”写入。
- 当前阶段只能做只读核查时，优先 `help` / `list` / `show` / `--dry-run`；把缺口明确交回对应领域技能或用户决定。

## 先分清 `data-app` 与 `analytic-app`

当前 CLI 里，很多数据层命令的 `--app` 实际是在指“承载数据集的数据包（data-app）ID”，不一定是最终给用户看的分析应用。

- `dataset` / `data-model` / `metric` / `measure` 往往要求 `--app <data_app_id>`
- `dashboard` 挂在最终要交付给用户的应用下，通常是 `analytic-app`
- `data-app` / 数据包应创建和检索在 `data-mart`，不要默认放在 `personal-area`
- 如果用户说“从零开始”，不要默认一个 app 可以跳过这层差异；先说明哪个 ID 是 `data-app`，哪个 ID 是 `analytic-app`

## 典型工作流

### 工作流 A：从数据到仪表盘

目标：从新 connection 出发，先把数据准备在 `data-app` 里，再把结果接到分析应用和仪表盘。

0. 如果还没有承载数据集的 `data-app`，先补一个容器
   - `hbi app create "销售数据准备" --app-type data-app --area data-mart`
1. `hbi-data`
   - `connection list/show/test`
   - `dataset create/list/show/preview`
   - 注意：`dataset create` 不是只有 `--connection`，还要带 `--app <data_app_id> --name --schema --table`
   - 如果任务实际变成 pipeline 节点编排、节点预览或 pipeline 调度，转 `hbi-pipeline`
2. `hbi-data-modeling`
   - `data-model show/preview/query`
   - `suggest-joins` / `join-add` / `join-list` / `join-delete`
   - 如果要给 `join-add` 示例，使用稳定形态：`--type left --on left_field=right_field`
3. `hbi-app`
   - 如果需要面向用户的分析应用，再 `app create --app-type analytic-app`
   - 如果需要把数据包接到分析应用，先 `app dataapp-replace <analytic_app_id> --list`
   - 后续 replace 映射再根据 `app dataapp-replace --help` 和返回的 source/target ID 明确填写，不要在本技能里猜载荷
4. `hbi-dashboard`
    - `dashboard create`
    - `dashboard plan apply`
    - 如果走 YAML 仪表盘方案，继续读 `hbi-dashboard/references/dashboard-plan.md`
    - 在本技能里停在 dashboard 阶段即可；控件级细节统一转 `hbi-dashboard`
    - 如果用户接着要对图表配置阈值预警、webhook/email 告警，再切 `hbi-data-alert`
5. `hbi-permission`
   - 团队授权优先 `authorize get/grant`
   - 只有用户明确说“发布到应用市场”或“生成分享链接”时，才进入 `app publish` / `app share`
   - 如果要给授权示例，使用稳定形态：`authorize get app <app_id>`、`authorize grant app <app_id> --user USER_ID:ROLE`、`authorize grant app <app_id> --organization ORG_ID:ROLE`

推荐起手命令：

```bash
hbi search --area personal-area --root --recursive --query "销售" --output json
hbi search --area personal-area --folder <folder_id> --recursive --query "销售" --output json
hbi connection list --output json
hbi app list --area data-mart --root --app-type data-app --output json
hbi app list --area personal-area --root --app-type analytic-app --output json
```

### 工作流 B：业务指标中心

目标：围绕业务指标、主题域、分析看板完成一套 measure-centric 方案。

1. `hbi-data`
   - `measure create/list/show`
2. `hbi-indicator-center`
   - `subject list/create/add-metrics/toggle-online/list-metrics`
   - `kanban create/add-metric/show/export`
3. `hbi-permission`
   - 如需共享看板或管理访问，再做授权

这是和普通 `dashboard` 不同的一条链。用户只要强调“业务指标中心”“主题域指标”“指标看板”，就优先切到 `hbi-indicator-center`，不要停留在泛泛的 data/dashboard 说明里。

### 工作流 C：组织与访问开通

目标：给新成员或新团队开通访问能力。

1. `hbi-user-mgmt`
   - `user create`
   - `user-group create/update`
   - `org list/trees`
2. `hbi-permission`
   - `authorize grant`
   - `permission app-get` / `folder-get` 验证结果

### 工作流 D：平台治理与租户管理

目标：在平台管理员视角治理租户、组织、用户与资源访问。

1. `tenant list/get/users/statistics`
2. `org sync` 或 `org trees`
3. `user` / `user-group` 调整成员
4. 必要时 `authorize` 统一授权

## 工作流中的搜索优先级

如果不知道资源 ID，先这样排查：

1. `search`
   - 例如：`hbi search --area personal-area --root --recursive --query "资源名" --output json`
   - 已知父目录、但不知道更深层位置时，可改用 `hbi search --area personal-area --folder <folder_id> --recursive --query "资源名" --output json`
2. 对应领域的 `list`
3. 对应领域的 `show`
   - `show` 的位置参数必须是 ID，不是名字

不要一上来就假设资源 ID 或路径。
`app-mart` 是扁平空间，搜索它时不要再带 `--root`、`--folder`、`--recursive`。

## 技能切换规则

- 数据连接、数据集、指标：切到 `hbi-data`
- 数据集成 pipeline、节点、pipeline 调度：切到 `hbi-pipeline`
- 数据科学 notebook、段落执行、notebook 调度：切到 `hbi-notebook`
- Data Agent / ChatBI / Copilot 配置、prompts、系统级向量库：切到 `hbi-data-agent`
- 已存在计划的 cron / 依赖 / 通知 / context / logs 治理：切到 `hbi-scheduler`
- 联表设计、主表/维表判断、关系验证：切到 `hbi-data-modeling`
- 应用生命周期：切到 `hbi-app`
- 仪表盘与元素：切到 `hbi-dashboard`
- 图表阈值预警、webhook/email 告警、data-alert validate/create/update：切到 `hbi-data-alert`
- 权限：切到 `hbi-permission`
- 用户、组织、租户：切到 `hbi-user-mgmt`
- 复杂表达式：切到 `hql-expert`

## 禁止事项

- 不要跨阶段传递未验证的 ID。
- 不要编造 `search --name` 这类参数，也不要把资源名字直接传给 `show`。
- 不要在 `data-app` 还没明确时，就把 `dataset` / `data-model` 的 `--app` 写成最终分析应用 ID。
- 不要在本技能里猜测 `join-add --join-type`、`element chart --chart-type` 这类未确认的子阶段参数。
- 不要在全链路回答里直接展开 `element chart`、`element filter` 的参数细节。
- 不要在应用不存在时创建仪表盘。
- 不要在主题域/业务指标链路里误用普通仪表盘思路。
- 不要在缺少权限现状核查时直接大规模授权。
