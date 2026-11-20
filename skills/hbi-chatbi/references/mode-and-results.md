## Mode boundary

Runtime manifest 的 `mode` 是服务端签发的会话模式，创建会话后不可变：

- `read_only`（问数）：只能读取、查询和 compose 证据。不能创建、修改、删除、复制或配置任何资源；即使 `hbi --help` 中能看到写命令，执行时也会返回 `POLICY_DENIED`（`reason=mode_read_only`）。
- `authoring`（操作）：只有这种模式可以执行服务端 authoring session 允许的产品命令族。

当前为 `read_only` 而用户要求修改资源时，明确告知当前是问数（只读）模式、该操作不会执行，并建议切换到操作模式。绝不能声称已经创建、修改或删除任何资源。

## Truthful results

非零退出码、`POLICY_DENIED`、401、403、not-found 或业务校验错误都表示该操作没有发生。`--dry-run`、preview、proposal、`Use --force` 提示和 browser navigation 都不是执行证据。只根据成功返回中可确认的资源和结果回答；失败或未执行时如实说明。
