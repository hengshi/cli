# Kanban Export Contract

在以下场景继续读取本参考：

- 需要给 `kanban export` 写 `--file/--value`
- 需要知道 CLI 在不传 payload 时会自动生成什么 body

## 默认行为

如果不传 `--file/--value`，CLI 会从当前 kanban layouts 自动生成：

```yaml
chartOptions:
  <layout_key>: <chart export body>
chartNames:
  <layout_key>: <export title>
```

空 kanban 的默认 body 固定为：

```yaml
chartOptions: {}
chartNames: {}
```

## `chartOptions.<layout_key>` 的稳定结构

每个有效 metric layout 当前会生成一份 object，稳定高频字段是：

| 字段 | 说明 |
|---|---|
| `name` | 导出图表类型；优先沿用 kanban layout/defaultChartType，缺失时回退 `KPI` |
| `version` | 图表版本 |
| `axes[]` | 从 dimensions/measures 组出来的图表轴 |
| `appId` | 主 app id |
| `dataAppId` | 数据包 app id；缺失时回退到 `appId` |
| `datasetId` | 主 dataset id |
| `where` | layout 自带 filters |
| `limit` | 可选 |
| `sort` | 可选 |
| `title` | 可选 |

最小示意：

```yaml
chartOptions:
  1:
    name: Bar
    version: 6100
    appId: 3034
    dataAppId: 3034
    datasetId: 4
    axes:
      - kind: dimension
        appId: 3034
        datasetId: 4
        fieldName: region
        axisName: group
      - kind: measure
        appId: 3034
        datasetId: 4
        fieldName: sales
        axisName: y
    where: []
chartNames:
  1: Revenue by Region
```

## override 规则

`--file/--value` 仍然要求 top-level object。

如果你传入 payload，CLI 会把它 deep-merge 到默认生成体上。因此最稳的做法是：

1. 先跑：

```bash
hbi kanban export <kanban_id> --dry-run --output json
```

2. 再从 dry-run 里的 `body` 出发改

例如只改某个 layout 的标题：

```yaml
chartNames:
  1: Executive Revenue
```

## 建议

- 如果用户只是想按当前 kanban 正常导出，不要手写 payload
- 只有在确实要覆盖 `chartOptions` / `chartNames` 时，才传 `--file` / `--value`
