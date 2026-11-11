# report service 报表查询指引

读取本文档后，回到 wepig 主流程继续执行：`endpoints --keyword <keyword>` 发现接口，`detail` 看参数，`call` 调用。报表接口属于 `report` service，tool 名形如 `report_...`（前缀 `/report` 已被剥离）。

## 领域 -> keyword

| 业务问题 | keyword（任选其一） |
| --- | --- |
| 生产日报 / 仪表盘 | `daily` / `production_daily` / `dashboard` / `prod` |
| 生产周报 / 月报 | `production_weekly` / `production_month` / `annual` |
| 存栏统计 / 明细 | `inventory` / `bred/inventory` / `inventory/statistics` / 存栏 |
| PSY / NPD / 受胎率等繁殖指标 | `psy` / `npd` / `analysis` |
| 结算 | `settlement` / `batch` |
| 公猪分析（生产/精液库存/性能） | `boar` / `semen_inventory` / `performance` |
| 母猪档案 / 母猪存栏分析 / 评级 | `sow` / `grade` / `sow/animal` |
| 育肥批次 | `porker` / `batch` / 育肥 |
| 后备猪 / 配种批次 / 倒三角周报 | `breeding/batch` / `bred` / `breeding_week` |
| 生长曲线 | `pig_growth_curve` / `growth_curve` |
| 年出栏 / 留存 / 死淘分析 | `retain` / `cull` / `flow` / `feeding_days_count` |
| 生产计划 / 待办 | `production/plan` / `production_todo` / `todo` |
| 猪场汇总 / 用户年度报告 | `system/summary` / `annual_report` |
| 自定义动物绩效 | `custom_animal_performance` |
| 母猪 ROI（看板/单头明细/断奶预测/行情设置） | `roi` / `sow_roi` |
| PRRS 风险预警（概览/单场详情/可关联预警周） | `prrs` / `prrs_warning` |
| 批次详情卡 | `batch_detail` |
| 年报智能解析 | `interpretation` / `annual` |
| 用户行为分析 | `user_behavior` |

若 `endpoints` 0 命中，按响应里的 `hint` 放宽 keyword；报表路径常以 `/report` 开头，tool 名中前缀已被剥离，直接用语义词（如 `daily`、`inventory`、`psy`）搜索即可。

## report 参数注意点

- 日期字段统一用 `YYYY-MM-DD`；日报/周报/月报通常以 `start_date` / `end_date` 为必填区间。
- 报表类接口常按“猪场 + 时间段”出汇总，过滤字段名不要猜测；先看 `detail` 的 `inputSchema`。
- 响应常含 `summary` / `pagination` / `x_cols_map` / `title` 等展示结构，按 `outputSchema` 判断展示字段。
- 报表接口计算量大，避免一次性拉超大时间范围；优先用汇总字段回答，必要时再取明细。
