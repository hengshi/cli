# Dataset Type Map

在以下场景继续读取本参考：

- 需要把前端“数据集创建”卡片上的中文类型名，对齐到 CLI 命令入口
- 需要判断某个词是 frontend create token、persisted dataset type，还是 CLI authoring surface
- 用户说“多表联合 / 数据聚合 / 行转列”，但你需要落成正确 CLI 命令

## 先记住三层概念

很多“数据集类型”问题，实际上混着三层名字：

1. **前端创建卡片 token**：例如 `connections`、`api_query`
2. **前端面向用户的中文名**：例如“数据连接”“API 查询”“多表联合”
3. **CLI / 持久化 authoring 面**：例如 `dataset create-api`、`dataset create-fusion`，以及 dataset `options.type`

不要把这三层直接当成一回事。

## 前端 create 卡片 ↔ CLI 入口对照

| 前端 create token | 前端中文名 | 释义 | CLI 稳定入口 | 常见持久化类型 / authoring 形态 |
|---|---|---|---|---|
| `connections` | 数据连接 | 基于数据连接里的表 / 视图创建数据集；卡片名为了简洁显示成“数据连接” | `hbi dataset create --app <data_app_id> --connection <connection_id> ...` | 常见落盘为 `connection` |
| `local_file` | 本地文件 | 基于上传文件创建数据集 | `hbi dataset create-from-file --app <data_app_id> ...` | file/imported dataset |
| `custom_sql` | SQL 查询 | 基于数据连接编写 SQL 创建数据集 | `hbi dataset create-custom-sql --app <data_app_id> ...` | 常见写面为 `custom_sql` |
| `api_query` | API 查询 | 基于 API 查询结果创建数据集 | `hbi dataset create-api --app <data_app_id> ...` | save-side `options.type = api` |
| `fusion` | 多表联合 | 基于多个数据集做关联 / join 后生成新数据集 | `hbi dataset create-fusion --app <data_app_id> ...` | `fusion` |
| `union` | 数据合并 | 把多个结构兼容的数据集按行追加合并 | `hbi dataset create-union --app <data_app_id> ...` | `union` |
| `aggregate` | 数据聚合 | 按维度聚合已有数据集，生成汇总结果 | `hbi dataset create-aggregate --app <data_app_id> ...` | `aggregate` |
| `reference` | 引用数据集 | 基于已有数据集创建一个引用 / 代理入口 | `hbi dataset create-reference --app <data_app_id> ...` | `reference` |
| `pivot` | 行转列 | 把行值展开为列 | `hbi dataset create-pivot --app <data_app_id> ...` | `pivot` |
| `unpivot` | 列转行 | 把多列折叠为行 | `hbi dataset create-unpivot --app <data_app_id> ...` | `unpivot` |
| `expect` | 敬请期待 | 占位卡片，不应在 CLI 里臆造稳定入口 | 不要在 CLI 里臆造入口 | 占位 / 未稳定开放 |

## 最容易混淆的点

### `connections` 不等于 CLI token `connection`

- 前端创建卡片写的是 `connections`
- 面向用户显示的是“数据连接”
- CLI 稳定写面是 connection-backed `dataset create ...`
- 这里的产品语义更接近“基于数据连接表创建数据集”，只是卡片文案为了简洁显示成“数据连接”
- 持久化 dataset type 常见仍是 `connection`

因此，**“数据连接”是产品词**，不是说 CLI 里一定存在一个同名 create token。

### `custom_sql` 也是 connection-backed，但不等于 `connections`

- `custom_sql` 和 `connections` 都依赖数据连接
- 区别在于：
  - `connections` 更接近“直接基于连接中的表/视图创建数据集”
  - `custom_sql` 更接近“基于连接编写 SQL 创建数据集”
- 对命令面来说，前者落到 `dataset create ... --connection ...`，后者落到 `dataset create-custom-sql ...`

因此，不要因为两者都 connection-backed，就把 `custom_sql` 折叠进 `connections`。

### `api_query` 不等于 persisted type `api`

- 前端创建卡片 token 是 `api_query`
- 前端中文名是“API 查询”
- CLI 入口是 `dataset create-api`
- 当前 save-side authoring contract 里，dataset `options.type` 要写的是 `api`

所以当用户说“API 查询数据集”时，命令面要落到 `create-api`，不要去猜 `type=api_query`。

## code-only / internal 类型

下面这些类型当前不应被当成稳定的用户 authoring 入口：

| 类型 | 当前判断 | 说明 |
|---|---|---|
| `extend` | internal / narrow | 更接近数据模型扩展，不是常规 create 卡片一等入口 |
| `append_file` | internal / narrow | 文件追加操作，不是常规 dataset create 卡片 |
| `_hs_memory` | internal | 内存临时数据集 |
| `internal_storage` | deprecated | 已废弃，不作为新写面 |

如果用户提到这些内部词，先回到真实用户目标，再选稳定命令树；不要直接把它们当成公开 create surface。
