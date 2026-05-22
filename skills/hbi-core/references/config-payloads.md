# Core Config Payloads

在以下场景继续读取本参考：

- 需要给 `auth config update`、`auth verify ldap`、`auth generate jwt-key`、`preferences ... update/verify` 写 `--file/--value`
- 需要判断某个配置面是不是“固定 schema”还是“动态对象，应该先 get 再回灌”

## 先记住这条总规则

`auth` / `preferences` 下面的很多 `--file/--value` 面，实际是**后端拥有的配置对象**，不是 CLI 自己重新发明的一套小 DSL。

因此最稳妥的工作流不是猜字段，而是：

1. 先 `get`
2. 再把返回对象导出成 YAML/JSON
3. 本地编辑
4. 先 `--dry-run` / `verify`
5. 再正式 `update`

## 快速矩阵

| 命令 | payload 类型 | 当前 source of truth |
|---|---|---|
| `auth config update <provider>` | object | `auth methods --output json` 的 `formItems` + `auth config get <provider>` |
| `auth verify ldap` | object | `auth config get ldap` / 现网 LDAP 配置对象 |
| `auth generate jwt-key` | object | `jwt-param generate-key` request body |
| `preferences <module> update` | object | 对应 `preferences <module> get` |
| `preferences smtp verify` | object | 对应 `preferences smtp get` |
| `preferences set-config <key> --value ...` | 任意 JSON/YAML 值 | 原始 escape hatch，没有模块级 schema |

## `auth config update <provider>`

支持的 provider 名要用稳定 CLI token：

- `ldap`
- `cas`
- `saml2`
- `oauth2`
- `jwt-param`
- `dingtalk`
- `wechat-work`
- `lark`
- `yunzhijia`
- `teams`
- `ctr`
- `qince`

### 结构规则

- payload 必须是 **object**
- CLI 不为所有 provider 固化一份静态字段表
- 安全来源是：

```bash
hbi auth methods --output json
hbi auth config get <provider> --output yaml
```

其中：

- `methods` 负责告诉你这个 provider 当前有哪些动态表单字段
- `config get` 负责给你一份可 round-trip 的当前配置对象

### LDAP 示例

```yaml
protocol: ldap
url: ldap.example.com
port: 389
bindUser: cn=Manager
bindPassword: secret
```

这不是 LDAP 的完整 schema，只是当前 CLI / E2E 已锁住的常见字段例子。

## `auth verify ldap`

- payload 仍然是 **object**
- 结构应与 LDAP 配置对象一致
- 最稳流程：

```bash
hbi auth config get ldap --output yaml > ldap.yaml
hbi auth verify ldap --file ldap.yaml --dry-run
hbi auth verify ldap --file ldap.yaml
```

不要传纯字符串、数字或数组。

## `auth generate jwt-key`

这是：

```bash
hbi auth generate jwt-key --value '...'
```

对应的 object payload。

当前 repo 里已显式锁住的稳定字段示例是：

```yaml
checkSignAlgorithm: HS256
```

如果环境里需要更多生成参数，应以当前后端接口 / 既有 request body 为准；CLI 本身不会再包装额外 wrapper。

## `preferences <module> update`

当前高频模块包括：

- `environment`
- `everest`
- `security`
- `smtp`
- `home`
- `app-mart-tag`
- `list-sort`
- `skin`
- `css`
- `js`
- `gis`
- `open-dwinfo`

### 结构规则

- `update` / `verify` payload 都必须是 **object**
- CLI 不要求 wrapper，例如不是：

```yaml
config:
  ...
```

而是直接传模块对象本身。

### 推荐写法

```bash
hbi preferences smtp get --output yaml > smtp.yaml
hbi preferences smtp verify --file smtp.yaml --dry-run
hbi preferences smtp update --file smtp.yaml --dry-run
```

或：

```bash
hbi preferences environment get --output yaml > env.yaml
hbi preferences environment update --file env.yaml
```

`environment` 这一支经常是平铺 key/value object；其他模块则按各自后端对象组织。当前 repo 没有再为每个模块固化一份静态字段字典，因此 **对应 `get` 输出就是最稳的编辑起点**。

## `preferences smtp verify`

- 与 `preferences smtp update` 一样，吃的是 SMTP 配置对象本身
- 不是布尔值，也不是单个地址字符串
- 如果只是想验证候选配置，直接把 `smtp get` 的结果改完后喂给 `verify`

## `preferences set-config <key> --value ...`

这是原始 escape hatch，不是模块化稳定 schema。

特点：

- 只有 `--value`，没有 `--file`
- `value` 可以是：
  - object
  - array
  - number
  - bool
  - string

示例：

```bash
hbi preferences set-config some.key --value '{"enabled":true}' --dry-run
hbi preferences set-config some.key --value '42' --dry-run
hbi preferences set-config some.key --value 'defaultLandingPage: app_mart' --dry-run
```

如果已经有模块化入口，优先用模块化入口，不要先跳到 `set-config` 猜裸 key。
