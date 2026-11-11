# query service 领域查询指引

读取本文档后，回到 wepig 主流程继续执行：`endpoints` 发现接口，`detail` 看参数，`call` 调用。

## 领域 -> keyword

| 业务问题 | keyword（任选其一） |
| --- | --- |
| 配种 / 妊娠 / 发情 | `breeding` / `pregnancy` / `gilt_heat` / 配种 / 妊娠 |
| 分娩 / 寄养 / 断奶 | `farrowing` / `fostering` / `weaning` / 分娩 / 断奶 |
| 仔猪 / 育肥流转（入栏/出栏/转群/销售） | `pig_farm_in` / `pig_farm_out` / `migrate` / `sell` / 转群 |
| 动物档案 / 个体信息 | `animal_list` / `animal_detail` / `animal_performance` / `eartag` / 档案 |
| 精液管理（库存/稀释/领用） | `semen_inventory` / `semen_list` / `semen_dilution` / 精液 |
| 遗传 / 基因 / 后代 | `genetics_offspring` / `genome` / 遗传 |
| 淘汰 / 死亡 | `cull` / 淘汰 |
| 考测 / 定级 / 背膘 | `backfat_test` / `fcr` / `on_test` / `classification` / 考测 |
| 审计 / 追溯 | `audit` / `tracking` |

若 `endpoints` 0 命中，按响应里的 `hint` 放宽 keyword，或改用英文路径词重试。

## query 参数注意点

- 日期字段统一用 `YYYY-MM-DD`。
- 分页字段通常是 `offset` / `limit`，实际必填和默认值以 `detail` 返回为准。
- 猪场、耳牌、个体、批次等过滤字段名称不要猜测；先看 `detail` 的 `inputSchema`。

## 示例 keyword 选择

- “本月后备母猪发情明细”：先试 `heat` 或 `gilt_heat`。
- “某猪场断奶记录”：先试 `weaning`。
- “动物档案/耳牌查询”：先试 `animal_list`、`animal_detail` 或 `eartag`。
- “精液库存”：先试 `semen_inventory`。
