---
name: hbi-user-mgmt
description: "用户与组织管理技能。凡是用户提到用户、用户组、组织、部门、租户、用户属性、平台管理、账号启停、密码重置、管理员重置、组织同步、租户引擎配置，或需要理解 `user`、`user-group`、`organization`、`org`、`tenant` 之间的边界时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi user --help"
---

# HBI User Management

> 前置：先读 `hbi-core`。涉及权限分配时，同时参考 `hbi-permission`。

## 资源边界

- `user`：用户账号本身
- `user-group`：用户组；当前实现底层仍走 organization/group 相关接口
- `org`：组织/部门树
- `user-attr`：用户属性
- `tenant`：租户，平台级资源

两个容易混淆的点：

1. `user-group` 和 `org` 不是同一个概念：前者更偏**用户集合**，后者更偏**部门树结构**。
2. 在 `user create/update` 里：
   - `--organization` 绑定的是**用户组**
   - `--org` 绑定的是**组织/部门**

## 常用命令入口

### 用户

`hbi user --help`：

- `list`
- `get`
- `create`
- `update`
- `delete`
- `enable`
- `disable`
- `reset-password`
- `roles`

### 用户组

`hbi user-group --help`：

- `list`
- `get`
- `create`
- `update`
- `delete`

### 组织

`hbi org --help`：

- `list`
- `get`
- `get-by-code`
- `trees`
- `sync`

### 用户属性

`hbi user-attr --help`：

- `list`
- `get`
- `create`
- `update`
- `delete`
- `values`

### 租户

`hbi tenant --help`：

- `list`
- `get`
- `create`
- `update`
- `delete`
- `enable`
- `disable`
- `users`
- `engine-config`
- `reset-password`
- `reset-admin`
- `statistics`

## 常见操作

### 用户账号：资料、状态、密码分开看

```bash
hbi user list --query "alice" --enable true
hbi user get <user_id>
hbi user roles
hbi user create \
  --name "Alice" \
  --email "alice@example.com" \
  --login-name "alice" \
  --password "secret" \
  --role 3 \
  --organization 12 \
  --org 34
hbi user update <user_id> --email "alice+new@example.com" --role 5
hbi user disable <user_id>
hbi user enable <user_id>
hbi user reset-password <user_id> --new-password "newsecret"
```

规则：

- 列表搜索用 `--query`，不要继续写旧的 `--q`
- `user roles` 现在直接列角色；`--list` 只是兼容旧用法
- `user update` 更适合资料、角色、用户组、组织关系更新
- 账号状态优先用 `user enable` / `user disable`
- 密码重置优先用 `user reset-password`
- 当系统开启管理员二次校验时，`user reset-password` 需要补 `--current-password`

### 用户组：可创建初始成员，更新成员会整体替换

```bash
hbi user-group list --query "分析师"
hbi user-group create "分析师团队" --description "BI 团队" --users "123,456"
hbi user-group get <group_id>
hbi user-group update <group_id> --users "123,456"
```

规则：

- `user-group create` 支持 `--users`，可以直接带初始成员
- `user-group update --users` 是**全量替换**，不是追加
- 位置参数名虽然叫 `<ORG_ID>`，但在这个命令面里它表示**用户组 ID**

### 组织/部门：树结构与外部同步

```bash
hbi org list --parent-id <org_id> --fetch-child true
hbi org get <org_id>
hbi org get-by-code "sales-dept"
hbi org trees
hbi org sync wecom --scheduler-period 24
```

- `org sync` 当前支持：`dingtalk` / `wecom` / `feishu`
- `--scheduler-period` 和 `--sync-interval` 都是同步调度参数

### 用户属性：能改范围与配置，不能改名

```bash
hbi user-attr list --query "region"
hbi user-attr create "region" --attr-type string --scope GLOBAL
hbi user-attr get <attr_id>
hbi user-attr update <attr_id> --scope INTERNAL --open-level HIDDEN
hbi user-attr values <attr_id>
```

规则：

- 搜索用 `--query`
- `create` / `update` 可配 `--options '<json>'`
- `user-attr update` 不支持改名；如果你问的是“重命名属性”，这不是稳定命令面

### 租户：治理、管理员恢复、引擎配置分开走

```bash
hbi tenant list --query "demo"
hbi tenant get <tenant_id>
hbi tenant create "Demo Corp" --code demo --login-name admin --password secret --tenant-type TEST
hbi tenant users <tenant_id> --role admin
hbi tenant engine-config get <tenant_id>
hbi tenant engine-config update <tenant_id> --enable false --disk-quota 2
hbi tenant reset-password <tenant_id> --login-name admin --new-password "newsecret"
hbi tenant reset-admin <tenant_id> --login-name "new-admin" --email "new-admin@example.com"
hbi tenant disable <tenant_id>
hbi tenant enable <tenant_id>
hbi tenant statistics
```

规则：

- 租户基础资料变更走 `tenant update`
- 单租户引擎能力/配额变更走 `tenant engine-config get|update`
- 租户管理员密码恢复走 `tenant reset-password`
- 租户管理员身份重置走 `tenant reset-admin`
- `reset-password` / `reset-admin` 不传 `--login-name` / `--email` 时，会回退到当前租户管理员
- 当系统开启管理员二次校验时，`tenant reset-password` 需要补 `--current-password`

## 推荐工作流

### 新用户入驻

1. `user roles` 先确认角色 ID。
2. `user create` 创建账号，并按需带 `--organization` / `--org`。
3. 需要补成员集合时，再走 `user-group create/update --users`。
4. 账号启停、密码重置优先走 dedicated 命令，不要把一切都塞进 `user update`。
5. 需要权限时，再转 `hbi-permission` 做授权。

### 平台级租户治理

1. `tenant list/get` 先确认租户。
2. `tenant users` 看租户内账号。
3. 管理员恢复走 `tenant reset-password` / `tenant reset-admin`。
4. 引擎能力或配额走 `tenant engine-config`。
5. 普通启停再用 `tenant enable` / `tenant disable`。

## 禁止事项

- 不要把 `user-group` 误当成部门树。
- 不要把 `user create/update --organization` 和 `--org` 当成同一类绑定。
- 不要继续把 `user roles --list` 当成主推荐写法。
- 不要把 `user-group update --users` 当成追加成员。
- 不要把 `tenant update` 当成 `tenant engine-config` / `tenant reset-admin` 的替代。
- 不要尝试用 `user-attr update` 重命名属性。
- 不要在普通租户场景下随意执行平台级 `tenant create/delete`。
