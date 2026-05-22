# Dataset / Metric / Measure Payload Contracts

在以下场景继续读取本参考：

- 需要给 `dataset create-api`、`dataset update`、`dataset replace`、`dataset export` 写 `--file/--value`
- 需要给 dataset 字段管理写 `dataset column-update` / `column-order` / `column-groups-apply`
- 需要给 `metric` / `measure` 写 `--display-format`
- 需要判断某次 `dataset update` 会走普通 `PUT` 还是前端同款 `/edit`
- 需要把 `dataset show --output json` 的结果改完再回灌

## 通用规则

- 本文只覆盖当前已固化的 `--file/--value` authoring 面，不覆盖所有后端 runtime 噪音字段。
- `dataset update --file/--value` 接受两种输入：
  1. 直接给 dataset `options` patch
  2. 直接喂 `dataset show --output json` 这类带顶层 `options` 的对象，CLI 会自动抽出 `options`
- 非 API dataset 的 `dataset update` 不负责字段 schema/type 变更；这类变更回到 `dataset column-update`
- 派生数据集（fusion / union / aggregate / pivot / unpivot）只有**纯重命名**时才走轻量 title update；一旦带 `--file/--value`，就进入受限的前端编辑合同

## dataset 字段管理：`column-update` / `column-order` / `column-groups-apply` / `column-copy-as` / `column-value-group-*` / `column-json-split-*`

### `dataset column-update`

`dataset column-update` 现在只暴露稳定单字段 flags：

1. **字段基础属性 flags**
2. **structured 展示格式 / 字段显示值 flags**

raw `--file/--value` patch 已不再作为 `column-update` 的 authoring surface。

前端字段管理功能名与 CLI surface 对照：

| 前端功能名 | CLI surface | 持久化位置 |
|---|---|---|
| 字段名称 / 显示名 | `--label` | `label` |
| 字段描述 | `--description` | `description` |
| 字段类型 | `--type` | top-level `type` |
| 字段用途 | `--purpose` | `purpose` |
| 显示 / 隐藏字段 | `--visible` | `visible` |
| 隐藏字段值 | `--hide-value` | `hideValue` |
| 展示格式 | `--display-format` / `--clear-display-format` | `config.formatter` |
| 展示格式 > 空值替换 | `--null-replace` / `--clear-null-replace` | `config.formatter.<type>.nullReplace` + `null_format` |
| 字段显示值 | `--display-value-*` / `--clear-display-value` | `enableDisplayValue + displayConfig` |

### 字段基础属性 flags

```bash
hbi dataset column-update --app 100 --dataset 200 --column amount \
  --label "Revenue" \
  --description "gross revenue" \
  --type number \
  --purpose measure \
  --visible true \
  --hide-value false
```

这些 flag 直接写字段对象上的稳定顶层键：

| CLI flag | 写入位置 |
|---|---|
| `--label` | `label` |
| `--description` | `description` |
| `--type` | top-level `type` |
| `--purpose` | `purpose` |
| `--visible` | `visible` |
| `--hide-value` | `hideValue` |

规则：

- 改字段类型时，只写 top-level `type`
- `basicType` / `originType` / `nativeType` 仍是读侧输出字段，不是稳定 authoring 面

### 展示格式 flags（`--display-format` / `--clear-display-format` / `--null-replace` / `--clear-null-replace`）

这里的中文功能名是前端 **展示格式**。字段 formatter 和 `metric` / `measure` 一样，写的是资源级 `config.formatter`：

```bash
hbi dataset column-update --app 100 --dataset 200 --column amount \
  --display-format '{"number":{"thousands":true,"decimal":2}}'
```

清空 formatter：

```bash
hbi dataset column-update --app 100 --dataset 200 --column amount \
  --clear-display-format
```

这里的 `--display-format` JSON 外层是 typed map：

```yaml
number:
  thousands: true
  decimal: 2
```

不要把 chart axis 那层的 inner leaf 直接误当成 dataset field 整体 payload。

空值替换现在也走同一层稳定 authoring：

```bash
hbi dataset column-update --app 100 --dataset 200 --column amount \
  --null-replace 0
```

清空空值替换（前端“不替换”）：

```bash
hbi dataset column-update --app 100 --dataset 200 --column amount \
  --clear-null-replace
```

规则：

- `--null-replace` 支持 number、`null`、带引号 JSON string，或直接传裸字符串
- CLI 会只改当前字段 type 对应的 formatter leaf，而不是粗暴覆盖整棵 `config.formatter`
- 清空时不会删除整个 formatter，而是写回前端同款 `nullReplace.op = null` + `null_format.type = "null"`

### 字段显示值 flags（`--display-value-*`）

这里的中文功能名是前端 **字段显示值**。它的稳定 authoring 面是：

- `enableDisplayValue`
- `displayConfig`

当前数据集 display field：

```bash
hbi dataset column-update --app 100 --dataset 200 --column user_id \
  --display-value-field user_name
```

“自显示值”快捷写法：

```bash
hbi dataset column-update --app 100 --dataset 200 --column user_id \
  --display-value-self
```

关联数据集 display field：

```bash
hbi dataset column-update --app 100 --dataset 200 --column user_id \
  --display-value-dataset 99 \
  --display-value-related-field user_id \
  --display-value-field user_name
```

清空 display value：

```bash
hbi dataset column-update --app 100 --dataset 200 --column user_id \
  --clear-display-value
```

对应的稳定 `displayConfig` shape：

| 场景 | `displayConfig` |
|---|---|
| 自显示值 | `{ datasetId: null, relatedFieldName: null, displayFieldName: "<当前字段名>" }` |
| 当前数据集 display field | `{ datasetId: null, relatedFieldName: null, displayFieldName: "<display field>" }` |
| 关联数据集 display field | `{ datasetId, relatedFieldName, displayFieldName }` |
| 清空 | `null` |

结论：

- **展示格式** = `config.formatter`
- **字段显示值** = `enableDisplayValue + displayConfig`
- 两者可以一起存在，但不是同一层 contract；不要把 `displayConfig` 塞进 formatter，也不要把 `nullReplace` 当成 display value

### `dataset column-order`

前端真实请求路径：

- `PUT /apps/{app}/datasets/{dataset}/fields/display-index`

CLI 稳定面：

```bash
hbi dataset column-order --app 100 --dataset 200 --fields order_id,store,amount
```

请求体：

```yaml
fieldsOrder:
  - order_id
  - store
  - amount
hsVersion: 7
```

规则：

- `--fields` 必须覆盖**当前数据集的全部字段且每个字段恰好一次**
- CLI 会先读当前 dataset 的 `hsVersion` 再发请求

### `dataset column-groups-apply`

前端真实请求路径：

- `PUT /apps/{app}/datasets/{dataset}/fields/groups`

CLI 输入 shape：

```json
[
  {
    "name": "Sales",
    "displayIndex": 1,
    "children": ["store", "amount"]
  },
  {
    "name": "Ops",
    "children": ["status"]
  }
]
```

CLI 会归一化成前端请求体：

```yaml
- name: Sales
  type: FIELD
  displayIndex: 1
  appId: 100
  children:
    - store
    - amount
- name: Ops
  type: FIELD
  displayIndex: 2
  appId: 100
  children:
    - status
```

规则：

- `displayIndex` 省略时，CLI 按输入顺序补 `index + 1`
- 每个 group 的 `children[]` 都必须是当前数据集里真实存在的字段名
- group 名必须非空且唯一
- 清空所有 field groups 时，直接传空数组 `[]`

### `dataset column-copy-as`

这对应字段管理页里的 **复制为**。

```bash
hbi dataset column-copy-as --app 100 --dataset 200 \
  --source calc_store \
  --name calc_store_copy \
  --label "Store copy"
```

CLI 会先读源字段，再走 `createNewColumnOfDataset` 同款 create body：

```yaml
options:
  label: Store copy
  visible: true
  type: string
  originType: string
  expr:
    kind: formula
    op: "{store}"
    value: "{store}"
  config: {...existing config...}
fieldName: calc_store_copy
```

边界：

- 只接受带 `expr` 的派生字段
- JSON split child（`expr.kind=function` + `op=jsonget`）不走 copy-as，而走 `column-json-split-*`

### `dataset column-value-group-create|update`

这对应字段管理页里的 **列值分组 / data_group**。它是**派生字段 authoring**，不是 `column-groups-apply` 那层字段分组。

scatter / `setgroup`：

```bash
hbi dataset column-value-group-create --app 100 --dataset 200 \
  --column city \
  --name city_band \
  --group-type scatter \
  --value '[{"name":"核心城市","values":["Shanghai","Hangzhou"],"isDefaultGroup":true},{"name":"其他","values":["Suzhou"]}]'
```

continuous / `rangegroup`：

```bash
hbi dataset column-value-group-create --app 100 --dataset 200 \
  --column amount \
  --name amount_band \
  --group-type continuous \
  --value '[{"name":"Small","toValue":100,"including":true},{"name":"Large"}]'
```

create 时，CLI 归一化成：

```yaml
options:
  label: amount_band
  visible: true
  type: string
  originType: string
  expr:
    type: string
    op: amount
    kind: rangegroup
    args:
      - kind: constant
        value: Small
        op: 100
        including: true
      - value: Large
fieldName: amount_band
```

规则：

- `scatter` -> `expr.kind = setgroup`
- `continuous` -> `expr.kind = rangegroup`
- `continuous` 只接受 `number` / `integer` / `date` / `time` base field
- base field 是 `json` 时，不走 value group，而走 `column-json-split-*`
- 新字段默认 `type/originType = string`
- `update` 读的是已有 group field 的 `expr.op` / `expr.kind`，不是重新发明另一套 patch 面

### `dataset column-json-split-show|apply`

这对应字段管理页里的 **JSON 拆列**。

查看当前 JSON 字段可拆 key：

```bash
hbi dataset column-json-split-show --app 100 --dataset 200 --column payload
```

apply 输入 shape：

```bash
hbi dataset column-json-split-apply --app 100 --dataset 200 --column payload \
  --value '[{"key":"user.name","fieldName":"user_name","label":"用户名","type":"string"}]'
```

CLI 会把它归一化成前端真实写 body：

```yaml
splitedFields:
  - label: 用户名
    fieldName: user_name
    type: string
    expr:
      kind: function
      op: jsonget
      args:
        - kind: field
          op: payload
        - kind: constant
          op: user.name
```

规则：

- `show` 走 `GET /field/split?fieldName=<jsonField>`
- `apply` 走 `PUT /field/split?fieldName=<jsonField>&hsVersion=...`
- backend typo 仍是 `splitedFields`，CLI 读侧接受 `splitedFields/splittedFields`，写侧固定发 backend 真实键
- `--column` 必须是顶层 JSON 字段，不是已有 split child

## `dataset create-api` / API 类型 `dataset update`

API dataset 当前接受两种等价输入形态。

### 1. 裸 `apiOptions` authoring 形态

```yaml
path: /orders
method: GET
params: []
headers: []
pageConfig:
  pageType: NONE
authConfig:
  authType: NONE
schema:
  - fieldName: order_id
    label: Order ID
    type: string
importType: 0
```

### 2. 包装后的 frontend save 形态

```yaml
importType: 0
options:
  type: api
  apiOptions:
    path: /orders
    method: GET
    params: []
    headers: []
    pageConfig:
      pageType: NONE
    authConfig:
      authType: NONE
  schema:
    - fieldName: order_id
      label: Order ID
      type: string
```

### 高优先级字段

| 字段 | 含义 | 约束 |
|---|---|---|
| `path` | API 路径 | 必填 |
| `method` | 请求方法 | `GET` / `POST` / `PUT` / `DELETE` |
| `params[]` | 请求参数声明 | 每项至少要有 `customFieldName` + `defaultValue` |
| `headers[]` | 请求头声明 | 每项至少要有 `headerName` + `headerValue` |
| `pageConfig.pageType` | 分页模式 | `NONE` / `PAGE` / `OFFSET` |
| `authConfig.authType` | 认证模式 | `NONE` / `OAUTH2` / `BASIC` |
| `schema[]` | 保存用 schema | 可省略，CLI 会先 preview 再回填 |
| `importType` | 导入模式 | 只接受 `0` 或 `1` |

### `pageConfig`

- `pageType = NONE` 时，最终会被收窄成：

```yaml
pageConfig:
  pageType: NONE
```

- `pageType = PAGE` 或 `OFFSET` 时，还需要：
  - `limit`
  - `limitName`
  - `offsetName`

### `authConfig`

- `authType = NONE` 时，最终会被收窄成：

```yaml
authConfig:
  authType: NONE
```

- `authType = OAUTH2` 时，还需要：
  - `tokenRequestUrl`
  - `clientId`
  - `clientSecret`
  - `tokenSendingMethod` (`HEADER` / `BODY` / `URL`)
  - `tokenName`
  - `responseFieldName`

- `authType = BASIC` 时，还需要：
  - `userName`
  - `password`

### 请求路径

- `dataset create-api`：先 preview，再 `POST /apps/{app}/datasets`
- API 类型 `dataset update --file/--value`：`POST /apps/{app}/datasets/{dataset}/edit`

## `dataset update --file/--value`

### 普通 non-API dataset：generic options patch

适用对象：

- connection dataset
- custom SQL dataset
- reference dataset
- 普通 file / imported dataset

输入是 dataset `options` patch，CLI 会先读取现有 dataset，再 merge：

```yaml
where:
  - kind: formula
    op: "{city} = 'Hangzhou'"
```

请求路径：

- `PUT /apps/{app}/datasets/{dataset}`

限制：

- 不要在这里改 `schema`
- 不要在这里用 `basicType` / `originType` / `nativeType` 伪装字段类型变更

### 派生数据集：稳定 `/edit` authoring 子集

| 数据集类型 | 当前稳定键 | 额外约束 | 请求路径 |
|---|---|---|---|
| `fusion` | `type`, `updateSchema`, `joinOpts`, `schema`, `uid`, `rootDatasetId`, `rootDatasetName`, `where` | 变更 join graph 时必须带 `schema`；`where` 里的公式只能引用持久化 fusion schema 字段，例如 `{id_1}` | `POST /apps/{app}/datasets/{dataset}/edit` |
| `union` | `type`, `updateSchema`, `unionOptions`, `schema` | 只要改 `unionOptions` 就必须一起给 `schema` | `POST /apps/{app}/datasets/{dataset}/edit` |
| `aggregate` | `type`, `rootDatasetId`, `aggregateOptions`, `schema` | 改 `aggregateOptions` 必须带 `schema`；切 root dataset 时必须一起给 `rootDatasetId + aggregateOptions + schema` | `POST /apps/{app}/datasets/{dataset}/edit` |
| `pivot` | `type`, `he`, `schema` | 改 `he` 必须一起给 `schema` | `POST /apps/{app}/datasets/{dataset}/edit` |
| `unpivot` | `type`, `he`, `schema` | 改 `he` 必须一起给 `schema` | `POST /apps/{app}/datasets/{dataset}/edit` |

### Fusion `where` 的额外规则

- `where[].kind = formula` 时，公式里**不能**再写 source-qualified 引用，例如 `{{123}}.{id}`
- 必须改成持久化 fusion schema 字段，例如 `{id_1}`
- 如果当前 fusion dataset 里还遗留旧的 source-qualified `where`，而这次 payload 又没有显式重写 `where`，CLI 会直接拒绝更新，避免把旧 shape 悄悄 replay 回去

## `dataset replace`

`dataset replace` 当前只有两条稳定 authoring 路：

1. `--source-file <path>`：文件替换
2. `--file` / `--value`：frontend `replaceDataset` body

不要把两条路混在一起。

### Generic replace body

`--file/--value` 接受两种形态：

1. 完整 request wrapper

```yaml
appId: 300
importType: 0
options:
  type: reference
  referenceOptions:
    sourceAppId: 300
    sourceDatasetId: 9
```

2. 裸 `options` 对象

```yaml
type: customSql
origin: custom_sql
connectionId: 12
path:
  - qa
customSql: select * from coffee_sales
schema:
  - fieldName: city
    label: city
    type: string
```

### 当前稳定判断

- reference / existed dataset / connection / custom SQL replacement 继续走这条 generic body
- file-backed replacement**不要**写 `options.type=upload`
- 如果 payload 里出现：

```yaml
options:
  type: upload
```

CLI 会直接拒绝，并提示改用：

```bash
hbi dataset replace --app <app_id> <dataset_id> --source-file ./data.csv
```

## `dataset export`

`dataset export` 的 `--file/--value` 是一个**可选 object body**。

- 不传 payload 时，body 默认为 `{}`，query 由 CLI 自动补：
  - `requestId`
  - `timeout=-1`
- 文件路径统一走 `--output-file`

当前 repo 里没有再往下细分一个更窄的静态 export body schema；如果用户确实要覆盖 body，最稳妥的来源是：

1. 先跑一次：

```bash
hbi dataset export --app <app_id> <dataset_id> --dry-run --output json
```

2. 再从 dry-run 结果里的 `body` 出发改写

如果用户没有明确的 frontend/export body 依据，优先**不传** `--file/--value`。

## `metric` / `measure`：`--display-format` 与 `--group`

当前 CLI 的稳定 authoring 目标：

- `--display-format`：写资源级 `config.formatter`
- `--group`：写 `tags.group[]`
- `metric show/list` 与 `measure show/list` 里的 `displayFormat` / `groups` 只是读侧投影，不是独立存储位置

### `--display-format` 的外层 shape：typed map

新 authoring 优先写前端当前 contract：

```json
{
  "number": {
    "thousands": true,
    "decimal": 2
  }
}
```

```json
{
  "date": {
    "aggregate": "month",
    "dateFormat": "YYYY-MM",
    "activeKey": "dateFormat"
  }
}
```

规则：

- `config.formatter` 的外层 key 是资源自己的 `type` 槽位，不是固定写死的 `formatter`
- 常见 key 包括 `number`、`percentage`，以及 date-like 类型；如果不确定 outer key，先跑 `metric show --output json` / `measure show --output json`
- chart 轴级 `axes[].formatter` 只吃**内层 leaf**，不吃这层 typed wrapper
- 前端读侧会容忍部分 legacy flat `config.formatter`，但新 CLI / agent authoring 不要依赖旧 shape

### 内层 leaf：`DisplayFormatter`

数据层 `config.formatter.<type>` 的 value，和图表轴级 `axes[].formatter`，使用的是同一套 flat leaf 字段。

#### 常见 number / date leaf 字段

| 字段 | 含义 | authoring 提示 |
|---|---|---|
| `prefix` | 前缀文本 | 稳定，可直接写 |
| `suffix` | 数值单位/缩写选择值 | 对应前端单位 selector；不是自由文本后缀 |
| `percent` | 百分比标记 | 常见值是 `%` |
| `unit` | 自定义后缀文本 | 稳定，可直接写 |
| `fillInDecimalPlaces` | 是否补齐小数位 | `true` 时按 `decimal` 补位 |
| `thousands` | 是否启用千分位 | 数字场景高频 |
| `decimal` | 小数位数 | 前端常见范围 `0..20` |
| `scientificNotation` | 是否启用科学计数法 | 通常与 `fillInDecimalPlaces` 二选一 |
| `showPlus` | 正数是否显示 `+` | 数字场景可直接写 |
| `showSuffix` | 是否显示 `suffix` 单位 | 兼容字段；KPI 更常见，普通图表不要默认加 |
| `aggregate` | 日期/时间格式对应的聚合粒度 | 常见如 `day` / `month` / `year` |
| `defaultAggrType` | `aggregate` 的 alias / 默认聚合回退 | 更偏资源回读/兼容；新 authoring 通常直接写 `aggregate` |
| `dateDowFormat` | 星期展示格式 | 例如短星期/长星期 |
| `dateNumberFormat` | 数字日期格式 | 数值化日期/周序号这类模式优先跟现有导出值走 |
| `dateFormat` | 主日期格式模板 | 例如 `YYYY-MM`、`YYYY-MM-DD` |
| `activeKey` | 当前启用的日期格式字段 | 只应是 `dateFormat` / `dateDowFormat` / `dateNumberFormat` 之一 |

#### `null_format` / `empty_format`

两者都是替换规则对象。

| 子字段 | 含义 | authoring 提示 |
|---|---|---|
| `type` | 替换模式或预设值 | 安全自定义写法是 `custom`；其它 preset 更适合从现有导出或 GUI 回写中复用 |
| `format` | 自定义替换文本 | 仅当 `type = custom` 时需要 |

一个稳定的自定义例子：

```json
{
  "number": {
    "null_format": {
      "type": "custom",
      "format": "N/A"
    },
    "empty_format": {
      "type": "custom",
      "format": "--"
    }
  }
}
```

#### `desensitization`

`desensitization` 是嵌套脱敏配置对象。

| 子字段 | 含义 | authoring 提示 |
|---|---|---|
| `prefix` | 前缀保留字符数 | 数字，常见如 `1` / `3` |
| `suffix` | 后缀保留字符数 | 数字，常见如 `1` / `4` |
| `mode` | 脱敏模式 | 前端已知值包括 `none` / `all` / `single` |
| `replaceValue` | 替换字符或预设 | 常见如 `*` / `X` / `custom` |
| `customValue` | 自定义替换字符 | 仅当 `replaceValue = custom` 时需要 |

#### 兼容 / 保留字段

| 字段 | 含义 | authoring 提示 |
|---|---|---|
| `formulaType` | formula 派生 formatter subtype | 偏 runtime/兼容字段；优先保留，不要凭空造 |
| `mode` | legacy flat 替换模式 | 新 authoring 优先写 `desensitization.mode` |
| `replaceValue` | legacy flat 替换字符 | 新 authoring 优先写 `desensitization.replaceValue` |
| `customValue` | legacy flat 自定义替换字符 | 新 authoring 优先写 `desensitization.customValue` |
| `nullReplace` | legacy dataset null replacer 对象 | 新 authoring 优先用 `null_format` / `empty_format` |

`nullReplace` 的子字段含义如下：

| 子字段 | 含义 | authoring 提示 |
|---|---|---|
| `op` | legacy null 替换操作值 | 更偏兼容迁移；不要新造 |
| `type` | legacy null 替换类型 | 更偏兼容迁移；不要新造 |
| `kind` | legacy null 替换 kind | 更偏兼容迁移；不要新造 |

### 与 dashboard / chart axis 的继承关系

把这三层分开理解，最不容易写错：

1. 数据层资源 formatter：`config.formatter.<type> = <DisplayFormatter leaf>`
2. 图表 field 轴继承：`usingDatasetFormatter: true`
3. 图表 formula 轴显式覆盖：`axes[].formatter = <DisplayFormatter leaf>`

也就是说：

- `metric` / `measure` 的 `--display-format` 吃的是 **typed map**
- chart 轴级 `formatter` 吃的是 **inner leaf**
- 这两层共用同一套 leaf 字段，但**不是同一个外层 JSON 形状**

最常见的两组对照：

```bash
hbi metric update --app <app_id> --dataset <dataset_id> amount \
  --display-format '{"number":{"thousands":true,"decimal":2}}'
```

```yaml
axes:
  - kind: field
    op: amount
    name: y
    usingDatasetFormatter: true
```

```yaml
axes:
  - kind: formula
    op: "sum({amount})"
    name: y
    formatter:
      thousands: true
      decimal: 2
```

日期字段同理：

```bash
hbi measure update --app <app_id> --dataset <dataset_id> order_date \
  --display-format '{"date":{"aggregate":"month","dateFormat":"YYYY-MM","activeKey":"dateFormat"}}'
```

```yaml
axes:
  - kind: formula
    op: "month({order_date})"
    name: group
    formatter:
      aggregate: month
      dateFormat: YYYY-MM
      activeKey: dateFormat
```

`enableDisplayValue` 走的是另一条链：

- 它依赖 dataset field 上的 `enableDisplayValue + displayConfig`
- 它**不**读取 `config.formatter`
- 所以 “显示值映射” 和 “日期/数字展示格式” 是两套独立合同

### `--group`

`--group sales,core` 最终会写成：

```json
{
  "tags": {
    "group": [
      { "name": "sales" },
      { "name": "core" }
    ]
  }
}
```

`measure create/update` 继续兼容旧的 `--tag` 长参数别名，但新写法优先统一到 `--group`。
