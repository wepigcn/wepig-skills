---
name: wepig
description: 用于处理微猪科技（wepig）生猪数字化管理平台中的猪场养殖业务。
---

# wepig 使用指南

用 `wepig` 完成授权、选组织、发现、看参数、调用五步。脚本已经封装 `/mcp` 访问细节。

## 渐进加载

先按用户问题直接使用脚本。只有在需要领域知识时才读取对应 reference：

| 场景 | 读取 |
| --- | --- |
| 配种、妊娠、分娩、断奶、动物档案、精液、流转、遗传、淘汰、考测、审计等养殖查询 | [references/query.md](references/query.md) |
| 生产日报/周报/月报、存栏统计、PSY/NPD、结算、公猪/母猪分析、母猪 ROI、PRRS 预警等报表 | [references/report.md](references/report.md) |
| 集团、公司、猪场、组织结构等后台管理查询 | [references/backstage.md](references/backstage.md) |
| 401/403、超时、0 命中、结果条数或字段异常等故障 | [references/troubleshooting.md](references/troubleshooting.md) |
| PSY/NPD/FCR/PRRS 等业务术语释义、用户口语与接口 keyword 对照 | [references/glossary.md](references/glossary.md) |

不要一次性加载所有 references。主流程、鉴权和命令语法以本文件为准；业务 keyword、参数约定和领域例子放在 reference 中。

## 鉴权

每个飞书用户使用各自的 API Key：CLI 会自动读取 cc-connect 注入的 `CC_SESSION_KEY`
（格式 `feishu:<chat_id>:<user_id>`），把鉴权文件写到 `~/.config/wepig/users/<user_id>/env`，
组织上下文也保存在同一目录。非 cc-connect 环境仍使用 `~/.config/wepig`。

飞书里用两步授权，避免命令阻塞：

```bash
wepig auth start   # 输出 verification_url 和 user_code；把 verification_url 原样发给用户
wepig auth poll    # 用户浏览器确认后执行，Key 保存到该用户自己的目录
```

`auth poll` 会一直轮询到用户确认（最长 10 分钟），执行时请把 Bash 超时设为 600000ms。

首次使用或当前用户没有可用 API Key 时，先进行登录引导，不要直接执行查询命令：说明需要授权，执行 `wepig auth start`，将返回的 `verification_url` 原样发给用户，并引导用户打开链接、使用 `user_code` 完成确认；用户确认后执行 `wepig auth poll`，授权成功再继续选择组织和查询。

备选：已有个人 API Key 时配置 WEPIG_API_KEY。注意环境变量优先于文件且对所有用户生效，不要全局设置。

## 组织上下文

一个 Key 可访问多个组织，调用前必须能唯一确定组织。组织优先级从高到低：

```text
--org TYPE:ID
> WEPIG_ORG 环境变量
> WEPIG_CONTEXT_FILE（默认 ~/.config/wepig/context）
> 当前 Key 唯一可访问的组织
> 报错，要求先选择
```

```bash
wepig orgs                       # 调 backstage_user_orgs，列出当前 Key 可访问的组织
wepig use <org_type>:<org_id>    # 用 orgs 返回的标识持久切换当前组织
```

用户给出组织名称时，必须先在 `wepig orgs` 的结果中按名称匹配，取得对应的 `<org_type>:<org_id>`，再执行 `wepig use`；不要猜测组织类型或 ID，也不要把名称直接传给 `wepig use`。

**执行 `tools`、`services`、`endpoints`、`detail` 或 `call` 前，必须先通过 `orgs` 并选择唯一组织。** CLI 会把 `user_org_type/user_org_id` 放进每次 MCP 请求（`tools/list` 的 `params`，工具调用的 `params.arguments`）；可用服务和工具由 API Key 与当前组织共同决定，切换组织后必须重新发现和确认工具。

## 工作流

先执行 `wepig tools`，以当前 API Key 和组织实际返回的工具及 schema 为准；不要假定只有查询工具，也不要凭猜测调用：

```bash
wepig tools
```

使用 `call_endpoint` 调用业务接口时，继续按以下顺序发现参数：

```bash
# 1. 发现接口：先用用户问题里的关键词；必要时参考 references 选 keyword
wepig endpoints --keyword <keyword>

# 2. 查看参数与响应结构：确认 required、字段类型、分页和日期要求；
#    若返回含 outputSchema，一并了解响应字段清单与类型
wepig detail <endpoint_name>

# 3. 调用接口：只传业务参数，key=value 会自动推断类型
wepig call <endpoint_name> key=value ...

# 4. 自主分析：检查数据范围、趋势、对比和异常；对可追踪异常继续按
#    endpoints -> detail -> call 查关联明细或对比数据
# 5. 结果转述：不要直接粘贴原始 JSON；按下方「结果呈现」整理成
#    用户问题对应的结论、证据、隐患与建议
```

如果不确定有哪些 service：

```bash
wepig services
```

多组织用户可对单次调用指定组织，不改变持久上下文：

```bash
wepig --org COMPANY:123 call <endpoint_name> key=value
```

## 自主分析与隐患钻取

查到业务数据后，无需等用户追问，先围绕用户问题分析再回答；组织列表、接口元数据等非业务数据不强行分析。

- **先界定数据范围**：确认时间、猪场、群体、样本量和分页是否完整。空结果、数据截断或口径不清时必须明确说明，不能据此作整体判断。
- **主动检查异常**：根据已有字段检查时间趋势、猪场/群体/批次差异、极端值、缺失/重复/口径冲突，以及繁殖、死淘、存栏、生长等指标的异常变化。不得编造行业阈值；没有可靠基准时，只能称为“数据内相对异常”或“待核查线索”。
- **发现线索就钻取**：当前工具支持时，主动沿“汇总 → 猪场/批次 → 个体/事件”查明细，或沿“异常期 → 历史/同期”做对比。每次仍须先发现接口并查看 schema，不猜接口和参数。只围绕异常做定向查询，查到足以解释、排除线索或确认现有数据不足后停止，不做无目标遍历。
- **区分事实与推断**：接口返回值是事实；自行计算的指标给出计算口径或对比基线；原因、影响和隐患只能作为明确标注的推断或待验证假设，不能把相关性写成因果，也不能仅凭查询数据作疾病诊断。
- **回答具体风险**：按“对象和时间 → 数据证据 → 可能影响 → 建议核查”说明隐患，并附关键数值。未发现明显异常时，只能表述为“在本次查询范围内未发现明显异常”，不等于排除所有风险；数据不足时直说，不强行找问题。
## 写操作边界

当前后端暴露的业务接口全部为只读查询（`query_*` / `report_*` / `backstage_*_list`）。若 `tools` / `endpoints` 实际返回中出现写接口（如 `create_` / `add_` / `save_` / `update_` / `delete_` 前缀），必须遵守：

- **用户未明确要求变更数据时，不调用任何写接口**；查询类问题一律用查询接口完成。
- 调用前用 `detail` 确认必填参数与枚举值，把将提交的参数整理成表格交给用户确认，确认后才执行 `call`。
- 删除、批量修改类操作必须显式二次确认，并说明影响范围。
- 写接口超时或报错后不得直接重试，先查询确认是否已生效，避免重复提交。
- 批量写入逐条调用，完成后汇总成功/失败清单；不承诺自动回滚。

## 结果呈现

`call` 返回的 JSON 是事实来源。回答用户时整理结构和重点，但不要翻译、改写或猜测接口返回的业务值。

- **先按用户问题组织答案**：用户问汇总就给结论和关键数字；用户问明细再给表格或列表。不要把完整 JSON 当作答案。
- **优先使用展示字段**：同一实体同时存在多个字段时，优先展示 `*_name`、`*_desc`、`*_label` 这类字段。只有在没有展示字段且用户问题需要定位记录时，才展示对应的 `*_id`、`*_code`、`*_origin`。
- **按 outputSchema 解读字段**：`detail` 返回的 `outputSchema` 给出响应字段清单与类型，是判断哪些字段值得展示的依据（用于区分展示字段与 id/code）。不是所有接口都声明了响应结构，缺失该字段时按字段名命名规则推断。
- **给出下一步建议**：完成自主分析和必要的关联查询后，仅对仍需用户决策、补充信息或当前工具无法完成的事项给出 1～3 条相关、可执行的后续建议；能够继续通过查询验证的线索应先按「自主分析与隐患钻取」处理，不要以建议代替钻取，也不要重复建议已完成的查询。没有合理建议时不要强行补充，不得基于未查询的数据作业务判断。

## 常用命令

| 子命令 | 作用 | 示例 |
| --- | --- | --- |
| `auth` | 浏览器授权并保存个人 API Key | `wepig auth` |
| `orgs` | 列出当前 Key 可访问的组织 | `wepig orgs` |
| `use` | 按 `orgs` 匹配的组织标识持久切换 | `wepig use <org_type>:<org_id>` |
| `tools` | 列出当前 Key 和组织支持的 MCP 工具 | `wepig tools` |
| `services` | 列出 service 及健康/接口数 | `wepig services` |
| `endpoints` | 按 keyword/domain/service 发现接口 | `wepig endpoints --keyword breeding` |
| `detail` | 取单个接口完整参数 schema（含必填项与响应结构 `outputSchema`） | `wepig detail query_event_breeding` |
| `call` | 调用接口 | `wepig call query_event_gilt_heat start_date=2026-06-01 end_date=2026-06-25` |
| `version` | 打印 CLI 版本号（仓库根 `VERSION` 文件） | `wepig version` |
| `check` | 检查 Skill/CLI 是否有新版本（`git fetch` 后比较上游 `VERSION`） | `wepig check` |

## 参数规则

- 不要传身份字段：`user_id`、`user_org_type`、`user_org_id` 由 CLI 或网关注入，脚本会拒绝。组织由 `--org`、`WEPIG_ORG` 或 `wepig use` 决定。
- 业务参数以 `key=value` 传入：`limit=100` 会转整数，`farm_ids=[1,2]` 会转数组，`start_date=2026-06-01` 保持字符串。
- 日期统一使用 `YYYY-MM-DD`。
- 相对日期（"本月""上周""近 30 天""今年"等）必须先取当前系统日期换算成具体 `YYYY-MM-DD` 区间再传参，不得凭记忆猜日期；周报等"周"的口径以 `detail` 的参数说明为准。
- 必填字段以 `detail <endpoint_name>` 返回的 `inputSchema.required` 为准。
- **分页拉全量**：列表接口通常用 `offset` / `limit` 分页（常见默认 `limit=10`）。需要汇总、统计或"全部"数据时，必须递增 `offset` 循环调用直至返回为空或不足一页，再合并结果；不得用第一页数据直接下全量结论。大时间范围报表按月或按猪场拆分多次调用再合并。
- 响应结构以 `detail` 返回的 `outputSchema` 为准；部分接口未声明响应结构，此时无该字段。

## 环境变量

| 变量 | 说明 |
| --- | --- |
| `WEPIG_API_KEY` | 个人 API Key（`auth` 以外的命令必填） |
| `WEPIG_ORG` | 当前组织，优先级低于 `--org`、高于本地 context |
| `WEPIG_URL` | 后端根地址，默认 `https://hi-api.wepig.cn` |
| `WEPIG_TIMEOUT` | 请求超时毫秒，默认 60000 |
| `WEPIG_CONFIG_DIR` | 配置目录；检测到 `CC_SESSION_KEY` 时自动为 `~/.config/wepig/users/<user_id>` |
| `WEPIG_CONTEXT_FILE` | 组织上下文文件路径，默认 `~/.config/wepig/context` |
