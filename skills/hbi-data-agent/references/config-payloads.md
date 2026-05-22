# Data Agent Config Payloads

在以下场景继续读取本参考：

- 需要给 `data-agent config update` / `data-agent config verify` 写 `--file/--value`
- 需要判断这里到底是“固定 schema”还是“先 get 再回灌”的动态对象

## 先记住这条规则

`data-agent config` 这条线当前是**后台配置对象直通后端**，不是 CLI 自己发明的简化 DSL。

所以最稳妥的工作流是：

```bash
hbi data-agent config get --output yaml > chat-config.yaml
hbi data-agent config verify --file chat-config.yaml --dry-run
hbi data-agent config update --file chat-config.yaml --dry-run
```

## `config update` / `config verify`

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
