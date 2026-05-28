---
name: hbi-permission
description: "权限领域技能。凡是用户提到文件夹权限、应用权限、应用授权快捷入口、授权查询、批量授权、回收授权、角色映射、平台或租户访问控制，或需要区分 `permission`、`authorize`、`app grant/revoke` 的职责时，都应该使用本技能。"
metadata:
  requires:
    bins: ["hbi"]
  cliHelp: "hbi permission --help"
---

# HBI Permission

> 前置：先读 `hbi-core`。如果权限动作只发生在应用级，也要同时参考 `hbi-app`。

## 权限相关概念

- `permission`：偏查询、查看现有权限记录
- `authorize`：偏写操作，做通用授权/回收授权
- `app grant` / `app revoke`：应用级快捷授权入口

本技能的核心价值，是避免把“查权限”和“改权限”混成一套命令。

## 常用命令入口

### `hbi permission --help`

- `folder-list`
- `folder-get`
- `app-list`
- `app-get`
- `app-rules`

### `hbi authorize --help`

- `get`
- `grant`
- `revoke`

### `hbi app --help` 里的权限快捷入口

- `permissions`
- `grant`
- `revoke`

### `authorize` 可操作的目标类型

- `app`
- `folder`
- `api-set`
- `connection`
- `kanban`

## 角色模型

这里有 **两套用户侧词汇**，不要混用：

| 命令面 | 用户侧词汇 | 适用范围 |
|---|---|---|
| `authorize grant` | `administrator` / `editor` / `viewer` / `tenant` | 通用授权 |
| `app grant --permission` | `admin` / `edit` / `view` | 应用级快捷授权 |

- `authorize grant` 底层角色仍然是 `ADMINISTRATOR / EDITOR / VIEWER / TENANT`
- `app grant` 只是把 app 场景收窄成更短的权限词
- `authorize get --action` 用的是 **动作 token**：`read` / `write` / `admin`，不是 `viewer` / `editor`

写自动化时，优先使用完整角色名，不要依赖缩写别名；但给 `app grant --permission` 时，请老老实实写 `view` / `edit` / `admin`。

## 查询权限

### 文件夹权限

```bash
hbi permission folder-list --area personal-area --user-id 123 --action read
hbi permission folder-get <folder_id> --area personal-area
```

`permission --area` 当前优先使用和 `search` / `app` 一致的小写连字符值，例如：

- `personal-area`
- `public-area`
- `app-mart`
- `system-portal`

CLI 也兼容后端风格的大写枚举，并会在发送请求前归一化，例如：

- `PERSONAL_AREA`
- `PUBLIC_AREA`
- `APP_MART`
- `SYSTEM_PORTAL`

### 应用权限

```bash
hbi permission app-list --area personal-area --user-id 123
hbi permission app-get <app_id> --area personal-area
hbi permission app-rules <app_id>
```

- `permission app-get` / `folder-get` 会返回更细的权限来源、间接来源、updater、grantors
- `permission app-rules` 是**只读查看**某个 app 的权限规则，不负责创建 / 更新 / 删除规则

### 应用级快捷查看与授权

```bash
hbi app permissions <app_id>
hbi app grant <app_id> --user 123 --permission edit
hbi app grant <app_id> --group 456 --permission view
hbi app revoke <app_id> --user 123
```

适用场景：

- 目标就是 **app**
- 主体只是 **user / group**
- 你想要一条更短、更贴近 GUI 的命令

规则：

- `app permissions` 返回的是 app 视角下的简化授权清单
- `app grant` / `app revoke` 只支持 `--user` / `--group`
- `app grant --permission` 只能写 `view` / `edit` / `admin`
- 如果你需要 `tenant`、`organization`、`org`、`comment`，或者目标不是 app，就切回 `authorize`

## 通用授权与回收

### 查看授权

```bash
hbi authorize get app <target_id>
hbi authorize get folder <target_id>
hbi authorize get app <target_id> --action read|write
```

- `--action` 过滤的是动作 token：`read` / `write` / `admin`
- 这不是角色过滤；不要写成 `viewer` / `editor`
- target type 建议写 canonical 值：`app` / `folder` / `api-set` / `connection` / `kanban`

### 授权

```bash
hbi authorize grant app <target_id> --user 123:viewer
hbi authorize grant folder <target_id> --organization 9:editor --org 456:viewer
hbi authorize grant connection <target_id> --user 123:viewer,456:editor --tenant 1:tenant
```

规则：

- `--user` 格式是 `USER_ID:ROLE`
- `--organization` 格式是 `ORG_ID:ROLE`，代表**组织**
- `--org` 格式是 `ORG_ID:ROLE`，代表**用户组**
- `--tenant` 格式是 `TENANT_ID:ROLE`
- 支持重复参数，也支持逗号分隔批量写法
- 至少要给一类主体：`--user` / `--organization` / `--org` / `--tenant`
- 建议外部文案统一写 `api-set`；`api_set` / `api` 这类别名虽然能被归一化，但不要把别名当 canonical 输出

### 回收授权

```bash
hbi authorize revoke app <target_id> --user 123,456
hbi authorize revoke folder <target_id> --organization 9 --org 789
hbi authorize revoke connection <target_id> --tenant 1
```

## 何时用哪套命令

- 只想看 **folder / app** 的权限来源、间接来源、updater：用 `permission`
- 只想看某个 app 当前有哪些 user/group 被授权：用 `app permissions`
- 想按 target type + target id 看授权，或按 `--action` 过滤：用 `authorize get`
- 要跨资源类型统一做授权：用 `authorize grant` / `authorize revoke`
- 只做应用级授权，且已经在应用上下文里：可用 `app grant` / `app revoke`
- 要创建 / 更新 / 删除 app 里的行级权限规则：转 `hbi-app` 的 `app rule`
  - agent-first 常用 typed surface：`app rule create-row|update-row`、`app rule create-column|update-column`
  - 应用级总开关走 `app rule enable|disable`（对应 app `options.enableAppRule`）
  - 复杂 raw payload 才退回 `app rule create/update --file|--value`

## 推荐执行顺序

1. 先 `show` / `list` 资源，确认目标 ID。
2. 再按问题选读面：`app permissions` / `permission` / `authorize get`。
3. 最后才做 `app grant` / `app revoke` 或 `authorize grant` / `authorize revoke`。
4. 变更后再执行一次查询，验证结果。

## 禁止事项

- 不要把 `permission` 当成写操作命令。
- 不要在同一段自动化里混写两种 area 风格；优先统一用小写连字符值。
- 不要把 `app grant --permission` 写成 `viewer` / `editor` / `administrator`。
- 不要把 `authorize get --action` 写成角色词；这里只认 `read` / `write` / `admin`。
- 不要把 `--organization` 和 `--org` 当成同一种主体。
- 不要写未校验的角色字符串。
- 不要在不知道目标类型是 `app`、`folder`、`connection` 还是 `kanban` 的情况下直接授权。
