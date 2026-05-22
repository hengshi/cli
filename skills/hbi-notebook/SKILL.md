---
name: hbi-notebook
description: "数据科学 notebook 技能。凡是用户提到 notebook、段落、paragraph、scientist、notebook 段落执行、段落语言探测、notebook 连接授权、notebook 调度创建，或需要围绕 `hbi notebook` 资源本体与段落运行工作时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi notebook --help"
---

# HBI Notebook

> 前置：先读 `hbi-core`。涉及数据连接与数据资产时，同时参考 `hbi-data`。复杂 HE/HQL 表达式设计再转 `hql-expert`。

## 资源边界

- `notebook` 是数据科学项目，不是 `pipeline`、`dataset` 或 `dashboard`。
- `paragraph` 是 notebook 内部段落；它有自己的 `paragraph_id`，不等于 `notebook_id`。
- `execute` 跑的是某个段落，会返回 `schema` / `data` / `logs` / `exception`。
- notebook 与 connection 之间是**关系对象**：`authorize` / `revoke` 改的是状态，`remove` 才是移除关系。
- `notebook schedule <id> create` 只负责创建执行计划；后续治理统一走顶层 `scheduler`。

两个容易混淆的点：

1. `transaction-mode` 是 notebook 事务模式：常见值是 `by-notebook` / `by-paragraph`。
2. paragraph 语言和连接不是一回事：当前环境先看 `notebook languages`；稳定公开值通常是 `sql`，部分环境会额外开放 `python`。

## 常用命令入口

`hbi notebook --help`：

- `list`
- `show`
- `create`
- `update`
- `delete`
- `paragraphs`
- `add-paragraph`
- `update-paragraph`
- `execute`
- `delete-paragraph`
- `connections`
- `add-connection`
- `authorize-connection`
- `revoke-connection`
- `remove-connection`
- `schedule`
- `languages`

## 常见操作

### Notebook 生命周期：先建项目，再改事务模式或名称

```bash
hbi notebook list --query "sales" --order-by updatedAt
hbi notebook create "Sales Lab" --transaction-mode by-notebook
hbi notebook show <notebook_id>
hbi notebook update <notebook_id> --name "Sales Lab v2" --transaction-mode by-paragraph
hbi notebook delete <notebook_id> --force
```

规则：

- 搜索用 `--query`
- 创建时就可以确定事务模式
- `notebook update` 至少要给 `--name` 或 `--transaction-mode` 之一

### 段落编写与执行：add / update / execute 分开看

```bash
hbi notebook languages --output json
hbi notebook paragraphs <notebook_id>
hbi notebook add-paragraph <notebook_id> "select 1 as one" --language sql --connection 144 --title "Sanity check"
hbi notebook update-paragraph <notebook_id> <paragraph_id> --content "select 2 as two" --connection 144
hbi notebook execute <notebook_id> <paragraph_id> --test --output json
hbi notebook delete-paragraph <notebook_id> <paragraph_id> --force
```

规则：

- `add-paragraph --language` / `update-paragraph --language` 先以 `notebook languages` 为准；当前后端稳定公开的是 `sql`，部分环境额外支持 `python`
- 不要把 `he` / `markdown` 当作当前稳定可建语言值
- `add-paragraph --previous` 用来控制插入位置
- `update-paragraph` 至少要给 `--content` / `--language` / `--connection` / `--title` 之一
- `execute` 会返回真实执行结果；如果存在 `exception`，CLI 会显式报错，不会默默吞掉

### Connection 关系：初始状态、授权切换、彻底移除要分开

```bash
hbi notebook connections <notebook_id> --output json
hbi notebook add-connection <notebook_id> --connection 144 --status valid
hbi notebook revoke-connection <notebook_id> 144
hbi notebook authorize-connection <notebook_id> 144
hbi notebook remove-connection <notebook_id> 144 --force
```

规则：

- `add-connection` 会创建 notebook 与 connection 的关系，可带初始状态 `valid` / `invalid`
- `revoke-connection` 把关系状态切到 `INVALID`
- `authorize-connection` 把关系状态切回 `VALID`
- `remove-connection` 才是把这条关系真正删除

### 支持语言与调度：创建计划走 notebook，后续治理转 `hbi-scheduler`

```bash
hbi notebook languages --output json
hbi notebook schedule <notebook_id> create --cron "0 0 ? * 1" --enabled --output json
hbi scheduler list --entity-group notebook --entity-key <notebook_id> --output json
hbi scheduler update <schedule_id> --disable
hbi scheduler delete <schedule_id> --force
```

规则：

- `notebook languages` 是语言能力来源，不要靠猜
- `notebook schedule` 当前主入口是 `create`
- 创建后调度实体会落成 `entityGroup=NOTEBOOK`
- 后续 list / show / update / switch / logs / delete 都走顶层 `scheduler`
- 如果用户的问题已经变成“拿 schedule / context 来排障或改计划细节”，切到 `hbi-scheduler`

## 推荐工作流

### 从实验到可重复运行

1. `notebook create` 先建项目并确定事务模式。
2. `add-connection` / `authorize-connection` 先把可用连接准备好。
3. `add-paragraph` / `update-paragraph` 逐步构造段落。
4. `execute` 验证输出是否有 `schema` / `data`，并显式处理异常。
5. 确认流程稳定后，再 `notebook schedule ... create`。

### 何时转到别的技能

- 要管理 connection / dataset / data-model 本体：转 `hbi-data`
- 要写复杂 HE/HQL 表达式：转 `hql-expert`
- 要把 notebook 结果编排进更长的交付链：转 `hbi-workflow`

## 禁止事项

- 不要把 notebook 当成 pipeline 或 dataset 的替代。
- 不要混淆 `notebook_id` 和 `paragraph_id`。
- 不要把 `revoke-connection` 当成 `remove-connection`。
- 不要在创建调度后继续试图用 `notebook schedule` 管全部治理动作；那是 `hbi-scheduler` 的职责。
- 不要把执行异常当成正常成功输出。
- 不要臆造未在 `notebook languages` / `--help` 里出现的语言值。
