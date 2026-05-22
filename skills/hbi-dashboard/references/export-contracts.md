# Dashboard Export Contracts

在以下场景继续读取本参考：

- 需要给 `dashboard export-data` / `dashboard export-file` 写 `--file/--value`
- 需要给 `element chart export-data` / `element chart export-file` 写 `--file/--value`
- 需要判断某条导出 payload 是“完整 export body”还是“filter shorthand”

## 通用规则

- 导出文件路径统一走 `--output-file`
- `--output json|yaml|table` 只控制 CLI 预览输出格式，不是导出文件格式
- `--dry-run --output json` 是最稳的 payload 观察入口

## `dashboard export-data` / `dashboard export-file`

这两条命令的 `--file/--value` 支持两种形态。

### 1. 完整 export body

CLI 会把下面这些 top-level key 视作“完整 DownloadDto-ish body”并直接使用：

- `app`
- `dashboard`
- `chartNames`
- `chartOuterWheres`
- `chartOptions`
- `queryString`
- `chartTypes`

也就是说，这类 payload 会被当成真正的 export body，而不是 filter shorthand：

```yaml
app:
  id: 20
dashboard:
  id: 1
chartOptions: {}
chartNames: {}
chartOuterWheres: {}
```

### 2. dashboard filter shorthand

如果 payload 不包含上面这些 key，CLI 会把它当成：

```yaml
<filter_uid>: <selected_value>
```

例如：

```yaml
FILTER_REGION:
  - East
PARAM_MONTH: 2024-01
```

这会被展开成：

```yaml
app:
  id: <app_id>
  options:
    filterMap: {}
dashboard:
  id: <dashboard_id>
  options:
    filterMap:
      FILTER_REGION: <expanded runtime filter value>
      PARAM_MONTH: <expanded runtime filter value>
chartOuterWheres:
  ...
```

说明：

- shorthand 只能覆盖当前 dashboard 已存在的 filter uid
- 如果 uid 不存在，CLI 会直接报错
- CLI 会根据 dashboard 当前 filterMap 和 chart chain 关系，自动补 `chartOuterWheres`
- 如果用户想覆盖 app 级 filter、queryString 或其他更深层字段，不要用 shorthand，直接给完整 export body

### query 与 body 的分工

- `dashboard export-data`
  - query 由 CLI 自动补：
    - `requestId`
    - `timeout=-1`
  - 如果命令行传了 `--chart-type`，它会进入 query

- `dashboard export-file`
  - query 由 CLI 自动补：
    - `requestId`
    - `timeout=170000`
    - `type`
    - `width`
    - `height`
    - `scale`

## `element chart export-data`

`chart export-data` 的 body 默认不是空对象，而是**当前持久化 chart runtime**。

也就是说，CLI 会先读 dashboard runtime，取出目标 chart，然后做：

```text
request body = persisted chart runtime
request body = deep_merge(request body, payload_override)
```

因此最稳的 payload 起点不是手写，而是：

1. 先看当前 runtime
2. 再按需要覆盖局部字段

### 推荐来源

```bash
hbi element chart show <chart_id> --dashboard <dashboard_id> --app <app_id> --output yaml
hbi element chart export-data <chart_id> --dashboard <dashboard_id> --app <app_id> --dry-run --output json
```

### 最小 override 示例

```yaml
where:
  - kind: formula
    op: "{region} = 'East'"
```

如果用户没有明确要 patch chart runtime，优先不传 `--file/--value`。

## `element chart export-file`

`chart export-file` 与 `chart export-data` 的关键区别是：

- query 承载了主要导出参数：
  - `type`
  - `width`
  - `height`
  - `scale`
- body 默认是：

```yaml
{}
```

CLI 当前没有再往下固化一个更窄的 file-export body schema；`--file/--value` 只是“把这个 object 作为 body 发出去”。

因此：

- 正常截图 / PDF / PNG 导出，优先只用命令 flags
- 只有在你已经有已知 frontend request body 时，才传 `--file/--value`

## 最稳的操作顺序

1. 先 `--dry-run --output json`
2. 如果是 dashboard 过滤导出，优先用 shorthand
3. 如果要改更深的 export body，再从 dry-run 结果里的 `body` 出发编辑
