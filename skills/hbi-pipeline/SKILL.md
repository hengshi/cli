---
name: hbi-pipeline
description: "数据集成领域技能。凡是用户提到 pipeline、数据集成、ETL、节点、source/transform/sink、节点预览、节点去重、pipeline 调度创建，或需要围绕 `hbi pipeline` 资源本体与节点图工作时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi pipeline --help"
---

# HBI Pipeline

> 前置：先读 `hbi-core`。涉及连接、数据集来源选择时，同时参考 `hbi-data`。
>
> 如果任务已经变成跨数据层、应用层、权限层的整条交付链路，再切 `hbi-workflow`。

## 资源边界

- `pipeline` 是**独立的数据集成资源**，不是某个 app 下的附属节点树。
- `pipeline` 负责 source / transform / sink 图结构，不等于 `dataset` / `data-model`。
- `pipeline node` 读取的是 pipeline 内某个节点的样本数据或去重值。
- `pipeline schedule <id> create` 只负责**创建**资源执行计划；后续查看、修改、停用、删除统一走顶层 `scheduler`。

两个容易混淆的点：

1. `<PIPELINE_ID>` 是 pipeline 资源 ID；`--uid` / `<NODE_UID>` 是 pipeline 内部节点标识，不是全局资源 ID。
2. `pipeline show` 看的是 pipeline 元信息与图结构；要看节点样本数据，走 `pipeline node data` / `distinct`，不是 `show`。

## 常用命令入口

### Pipeline 生命周期

`hbi pipeline --help`：

- `list`
- `show`
- `create`
- `update`
- `delete`
- `duplicate`
- `status`
- `errors`
- `schedule`
- `node`
- `edit`

### 节点读取

`hbi pipeline node --help`：

- `list`
- `data`
- `distinct`

### 节点编辑

`hbi pipeline edit --help`：

- `add`
- `remove`
- `connect`

当前稳定支持的节点类型包括：

- Source：`CONNECTION` / `FILE` / `DATASET` / `SQL`
- Transform：`SELECT` / `JOIN` / `AGGREGATE` / `PIVOT` / `UNION` / `UNPIVOT`
- Output：`SINK`

## 常见操作

### Pipeline 生命周期：先确认资源，再进图编辑

```bash
hbi pipeline list --query "sales" --status RUNNING
hbi pipeline create "sales-etl" --description "sales data cleanup"
hbi pipeline show <pipeline_id>
hbi pipeline update <pipeline_id> --name "sales-etl-v2"
hbi pipeline duplicate <pipeline_id> --name "sales-etl-copy"
hbi pipeline status <pipeline_id>
hbi pipeline errors <context_id>
```

规则：

- `pipeline` 是独立资源；不要先假设它挂在某个 `data-app` 下面。
- `status` / `errors` 关注的是执行上下文，不是节点样本预览。
- 真正进入节点层后，再转 `node` / `edit`。

### 节点读取：样本数据和去重值都走 node 面

```bash
hbi pipeline node list <pipeline_id>
hbi pipeline node data <pipeline_id> <node_uid> --limit 100
hbi pipeline node distinct <pipeline_id> <node_uid> order_status --limit 50
```

规则：

- `node data` 适合看某一步的 schema 和样本数据。
- `node distinct` 适合快速验证某字段值域。
- 这两类命令都要求你提供 **pipeline id + node uid**，不要只给资源名。

### 节点编辑：先建节点，再连线，是最稳定的默认工作流

```bash
hbi pipeline edit add <pipeline_id> \
  --uid input_1 \
  --nodetype CONNECTION \
  --title "Orders Source" \
  --connection-id 144 \
  --schema public \
  --table orders

hbi pipeline edit add <pipeline_id> \
  --uid select_1 \
  --nodetype SELECT \
  --title "Keep core fields" \
  --field order_id \
  --field customer_id \
  --field order_status

hbi pipeline edit connect <pipeline_id> select_1 --from-uid input_1
```

更复杂的节点参数边界：

```bash
hbi pipeline edit add <pipeline_id> \
  --uid dataset_1 \
  --nodetype DATASET \
  --title "Reference Dataset" \
  --app-id 2001 \
  --dataset-id 3002

hbi pipeline edit add <pipeline_id> \
  --uid join_1 \
  --nodetype JOIN \
  --title "Orders + Users" \
  --left-source-uid orders_1 \
  --right-source-uid users_1 \
  --left-field user_id \
  --right-field id \
  --join-type left_join
```

规则：

- `CONNECTION` 节点要求 `--connection-id`、`--schema`、`--table` 一起给。
- `DATASET` 节点要求 `--app-id` 和 `--dataset-id` 成对出现。
- `SQL` 节点里 `--connection-id` 和 `--sql` 也是成对出现。
- `JOIN` 如果用一次性完整表单，`--left-source-uid` / `--right-source-uid` / `--left-field` / `--right-field` 必须一起给；`--join-condition-op` 当前稳定值就是 `=`
- `UNPIVOT` 需要 `--group-name-field` / `--group-field-type` / `--number-field-name` / 至少一个 `--transfer-column`
- 除了这种“完整表单”场景，默认优先**先 add 再 connect**，比把一切都塞进 `add` 更稳

### 调度：创建计划走 pipeline，后续治理转 `hbi-scheduler`

```bash
hbi pipeline schedule <pipeline_id> create --cron "0 0 * * *" --enabled --output json
hbi scheduler list --entity-group pipeline --entity-key <pipeline_id> --output json
hbi scheduler update <schedule_id> --disable
hbi scheduler delete <schedule_id> --force
```

规则：

- `pipeline schedule` 当前主入口是 `create`
- 创建后，调度资源会落成 `entityGroup=PIPELINE`
- 后续的 list / show / update / switch / logs / delete 都走顶层 `scheduler`
- 如果用户的问题已经变成“我手里有 schedule id / context id，要看日志、改依赖、改失败通知”，就切到 `hbi-scheduler`

## 推荐工作流

### 从 source 到可运行 pipeline

1. `pipeline list/show` 先确认是否已有同类资源。
2. `pipeline create` 建空 pipeline。
3. `pipeline edit add` 先补 source 节点，再补 transform / sink。
4. 每接完一层，用 `pipeline node data` / `distinct` 验证结果。
5. 确认整条图稳定后，再 `pipeline schedule ... create`。

### 何时转到别的技能

- 要找 connection / dataset 本体：转 `hbi-data`
- 要做 dataset / data-model 的正式建模：转 `hbi-data` 或 `hbi-data-modeling`
- 要编排“pipeline -> dataset -> app -> dashboard”整条链：转 `hbi-workflow`

## 禁止事项

- 不要把 `pipeline` 当成 app 内部资源。
- 不要用 `pipeline show` 代替 `pipeline node data` / `distinct`。
- 不要忘记 `--uid`；节点标识不是自动推出来的。
- 不要只给半套节点参数，例如只给 `--app-id` 不给 `--dataset-id`。
- 不要把 `pipeline` 图连接和 `data-model join-add` 混成同一类建模动作。
- 不要把创建后的调度治理继续留在 `pipeline schedule`，那是 `hbi-scheduler` 的职责。
- 不要臆造节点位置、画布坐标之类 CLI 还没承诺的字段。
