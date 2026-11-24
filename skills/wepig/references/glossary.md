# 领域术语表

用户口语、业务黑话与接口 keyword 的对照。释义用于理解问题；选接口仍回到主流程 `endpoints` → `detail` → `call`。

## 繁殖指标

| 术语 | 释义 | keyword / 接口 |
| --- | --- | --- |
| PSY | 每头母猪每年提供的断奶仔猪数，繁殖效率核心指标 | `psy` → `report_psy_analysis` |
| NPD | 非生产天数：母猪既未妊娠也未哺乳的天数，越低越好 | `npd` → `report_npd_analysis` |
| 受胎率 / 分娩率 | 配种后成功妊娠 / 分娩的比例 | `analysis` / `psy` |
| 窝均断奶 | 每窝平均断奶仔猪数，PSY 的构成因子 | `weaning` / `farrowing` |

## 生长与测定

| 术语 | 释义 | keyword / 接口 |
| --- | --- | --- |
| FCR / 料肉比 | 饲料转化率：增重 1kg 消耗的饲料 kg 数，越低越好 | `fcr` → `query_event_fcr_determine` |
| 背膘 | 背膘厚度，种猪选育与体况评估指标 | `backfat_test` → `query_event_backfat_test` |
| 考测 / 测定 | 生长性能测定，含开测（on_test）与结测（off_test） | `on_test` / `off_test` |
| 定级 / 分级 | 按测定结果对个体分级 | `classification` / `grading` |
| 生长曲线 | 体重随日龄变化的曲线 | `pig_growth_curve` / `growth_curve` |

## 猪群分类

| 术语 | 释义 | keyword / 接口 |
| --- | --- | --- |
| 后备母猪（gilt） | 尚未配种分娩的年轻母猪 | `gilt_heat`（后备发情） |
| 经产母猪（sow） | 已分娩过的母猪 | `sow` / `sow/animal` |
| 公猪（boar） | 种公猪，含生产与精液分析 | `boar` |
| 仔猪 / 育肥猪（porker） | 哺乳仔猪 / 育肥阶段猪只 | `piglet_weaning` / `porker` |

## 生产事件链

| 术语 | 释义 | keyword / 接口 |
| --- | --- | --- |
| 发情 → 配种 → 妊娠 → 分娩 | 繁殖事件主线，按阶段查询 | `gilt_heat` / `breeding` / `pregnancy` / `farrowing` |
| 寄养 | 将仔猪转由其他母猪哺乳 | `fostering` |
| 断奶 | 仔猪离乳，繁殖周期节点 | `weaning` / `piglet_weaning` |
| 流转 | 入栏、出栏、转群、销售等位置/权属变更 | `pig_farm_in` / `pig_farm_out` / `migrate` / `sell` |
| 淘汰 / 死亡 | 主动淘汰（含淘汰申请）与死亡记录 | `cull` / `cull_animal_request` |
| 留存 | 留作种用未出售的个体 | `retain` |

## 精液管理

| 术语 | 释义 | keyword / 接口 |
| --- | --- | --- |
| 采精 → 稀释 → 领用 | 精液处理主线 | `semen_collection` / `semen_dilution` / `semen_outbound` |
| 精液库存 / 质检 | 库存量与质量检查 | `semen_inventory` / `semen_check` |

## 报表与专项

| 术语 | 释义 | keyword / 接口 |
| --- | --- | --- |
| 生产日报 / 周报 / 月报 | 按周期的生产汇总 | `production_daily` / `production_weekly` / `production_month` |
| 倒三角周报 | 配种批次维度的周度分析 | `breeding_week` → `report_batch_breeding_week` |
| 结算 | 批次维度的成本/收益结算 | `settlement` → `report_settlement_batch` |
| 母猪 ROI | 单头母猪投入产出分析，含看板、明细、断奶预测 | `roi` / `sow_roi` |
| PRRS（蓝耳病） | 猪繁殖与呼吸综合征，平台提供风险预警 | `prrs` → `report_prrs_warning_overview` / `report_prrs_warning_farm_detail` |
| 审计 / 追溯 | 操作审计与事件追溯 | `audit` / `track`（`query_track_breeding` / `query_track_weaning`） |
