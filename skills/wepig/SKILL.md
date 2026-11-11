---
name: wepig
description: 用于调用 wepig SaaS MCP 工具，处理猪场养殖业务。先用 tools 查看当前 API Key 和组织支持的工具，再按工具 schema 调用。
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

不要一次性加载所有 references。主流程、鉴权和命令语法以本文件为准；业务 keyword、参数约定和领域例子放在 reference 中。

## 鉴权

默认用浏览器授权，无需手工拷贝凭证：

```bash
wepig auth
```

命令会打印授权地址和授权码，并在浏览器打开确认页；确认后个人 API Key 自动写入 `~/.config/wepig/env`（权限 600）。

备选：已有个人 API Key 时直接配置环境变量。

```bash
export WEPIG_API_KEY=你的个人 API Key
```

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
wepig orgs              # 调 backstage_user_orgs，列出当前 Key 可访问的组织
wepig use COMPANY:123   # 持久切换当前组织
```

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

# 4. 结果转述：不要直接粘贴原始 JSON；按下方「结果呈现」整理成
#    用户问题对应的结论、表格或列表
```

如果不确定有哪些 service：

```bash
wepig services
```

多组织用户可对单次调用指定组织，不改变持久上下文：

```bash
wepig --org COMPANY:123 call <endpoint_name> key=value
```

## 结果呈现

`call` 返回的 JSON 是事实来源。回答用户时整理结构和重点，但不要翻译、改写或猜测接口返回的业务值。

- **先按用户问题组织答案**：用户问汇总就给结论和关键数字；用户问明细再给表格或列表。不要把完整 JSON 当作答案。
- **优先使用展示字段**：同一实体同时存在多个字段时，优先展示 `*_name`、`*_desc`、`*_label` 这类字段。只有在没有展示字段且用户问题需要定位记录时，才展示对应的 `*_id`、`*_code`、`*_origin`。
- **按 outputSchema 解读字段**：`detail` 返回的 `outputSchema` 给出响应字段清单与类型，是判断哪些字段值得展示的依据（用于区分展示字段与 id/code）。不是所有接口都声明了响应结构，缺失该字段时按字段名命名规则推断。

## 常用命令

| 子命令 | 作用 | 示例 |
| --- | --- | --- |
| `auth` | 浏览器授权并保存个人 API Key | `wepig auth` |
| `orgs` | 列出当前 Key 可访问的组织 | `wepig orgs` |
| `use` | 持久切换当前组织 | `wepig use COMPANY:123` |
| `tools` | 列出当前 Key 和组织支持的 MCP 工具 | `wepig tools` |
| `services` | 列出 service 及健康/接口数 | `wepig services` |
| `endpoints` | 按 keyword/domain/service 发现接口 | `wepig endpoints --keyword breeding` |
| `detail` | 取单个接口完整参数 schema（含必填项与响应结构 `outputSchema`） | `wepig detail query_event_breeding` |
| `call` | 调用接口 | `wepig call query_event_gilt_heat start_date=2026-06-01 end_date=2026-06-25` |

## 参数规则

- 不要传身份字段：`user_id`、`user_org_type`、`user_org_id` 由 CLI 或网关注入，脚本会拒绝。组织由 `--org`、`WEPIG_ORG` 或 `wepig use` 决定。
- 业务参数以 `key=value` 传入：`limit=100` 会转整数，`farm_ids=[1,2]` 会转数组，`start_date=2026-06-01` 保持字符串。
- 日期统一使用 `YYYY-MM-DD`。
- 必填字段以 `detail <endpoint_name>` 返回的 `inputSchema.required` 为准。
- 响应结构以 `detail` 返回的 `outputSchema` 为准；部分接口未声明响应结构，此时无该字段。

## 环境变量

| 变量 | 说明 |
| --- | --- |
| `WEPIG_API_KEY` | 个人 API Key（`auth` 以外的命令必填） |
| `WEPIG_ORG` | 当前组织，优先级低于 `--org`、高于本地 context |
| `WEPIG_URL` | 后端根地址，默认 `https://hi-api.wepig.cn` |
| `WEPIG_TIMEOUT` | 请求超时毫秒，默认 60000 |
| `WEPIG_CONTEXT_FILE` | 组织上下文文件路径，默认 `~/.config/wepig/context` |
