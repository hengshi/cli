# Data Agent Config Payloads

在以下场景继续读取本参考：

- 需要给 `data-agent config update` / `data-agent config verify` 写 `--file/--value`
- 需要判断这里到底是“固定 schema”还是“先 get 再回灌”的动态对象

## 功能点速查

| 用户说法 / 中文术语 | 稳定入口 | payload root / shape | 说明 |
|---|---|---|---|
| ChatBI 主配置 / Data Agent 配置 / Copilot 后台配置 | `data-agent config get|verify|update` | 顶层配置对象本身 | 没有额外 `config:` wrapper |
| 校验候选 ChatBI 配置 | `data-agent config verify` | 顶层配置对象本身 | 与 update 吃同一份 object，只是走 verify request |
| 正式更新 ChatBI 配置 | `data-agent config update` | 顶层配置对象本身 | 最稳 workflow 是 `get -> verify -> update` |
| Prompt 模板 / basePrompt 文本 | `data-agent prompt get|update` | **不在本参考里** | 这是纯文本，不是 config object |
| 系统级向量库初始化 / 状态 | `data-agent vector init|status` | **不在本参考里** | 没有 `--file` / `--value` payload |

## 先记住这条规则

`data-agent config` 这条线当前是**后台配置对象直通后端**，不是 CLI 自己发明的简化 DSL。

所以最稳妥的工作流是：

```bash
hbi data-agent config get --output yaml > chat-config.yaml
hbi data-agent config verify --file chat-config.yaml --dry-run
hbi data-agent config update --file chat-config.yaml --dry-run
```

## `config update` / `config verify`

如果用户说的是这些功能点，它们在当前 CLI 里都仍然落到**同一个顶层配置对象**上：

- ChatBI 开关 / AI 配置开关
- model / API 地址 / provider 绑定
- prompt 关联配置
- 其他主配置字段

也就是说：先 `config get` 拿到现网对象，再在那份对象上找到对应 key 修改；不要凭空猜字段名。

### payload 规则

- 都要求 **JSON/YAML object**
- 不接受纯字符串、数字、布尔值、数组
- 没有额外 wrapper；不要写成：

```yaml
config:
  ...
```

而是直接传配置对象本身。

### source of truth

当前 repo 没有再为 `/configurations/chat` 固化一份完整静态字段表；最稳的字段来源是：

```bash
hbi data-agent config get --output json
```

也就是说：

- `get` 返回什么对象，`verify/update` 就按那份对象编辑
- 如果环境不同、后端版本不同，具体 key 可能也不同

## 这条参考不覆盖什么

- `prompt update`：它吃的是纯文本，不是 JSON/YAML object
- `vector init` / `vector status`：这两条没有 `--file` / `--value`

## 推荐动作

1. 先 `config get`
2. 基于返回对象编辑
3. 先 `config verify`
4. 再 `config update`

如果用户没有现成的 `config get` 输出，就不要凭空猜 ChatBI 配置字段。
