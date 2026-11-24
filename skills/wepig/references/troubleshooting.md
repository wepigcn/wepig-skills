# 故障排查指引

调用失败或结果异常时按本页定位，处理后回到主流程继续执行。不要对同一失败命令盲目重试。

## 401 / 鉴权失败

- 常见原因：`WEPIG_API_KEY` 环境变量与 `~/.config/wepig/env` 中的 Key 不一致（环境变量优先，CLI 会向 stderr 输出一行提醒），或 Key 已失效。
- 处理：先检查 stderr 是否有环境变量覆盖提醒；有则 `unset WEPIG_API_KEY` 或修正其值。仍失败则重新执行 `wepig auth` 完成浏览器授权。
- 不要在回答中打印完整 API Key。

## 403 `Selected organization is unavailable`

- 常见原因：组织上下文与后端地址不匹配。组织选择按 `<baseUrl>` 分键存储，用 `WEPIG_URL` 切换到 pre 等环境后，prod 保存的组织不能复用。
- 处理：在当前 `WEPIG_URL` 下重新执行 `wepig orgs`，再用 `wepig use <org_type>:<org_id>` 选择；或确认是否误设了 `WEPIG_URL` / `--org` / `WEPIG_ORG`。

## `endpoints` 0 命中

- 按响应里的 `hint` 放宽 keyword，去掉过长的限定词。
- 中英文互换重试（如 `断奶` ↔ `weaning`）。
- 仍无结果时执行 `wepig services` 确认 service 是否在当前组织可用，或 `wepig tools` 查看工具全集；不要用猜测的接口名直接 `call`。

## 超时

- 默认超时 60000ms，可用 `WEPIG_TIMEOUT` 调大。
- 报表类接口避免一次拉超大时间范围：按月或按猪场拆分多次调用再合并，比单纯加大超时更可靠。
- 查询接口超时可重试；写接口超时后不得直接重试，先查询确认是否已生效，避免重复提交。

## 结果与预期不符

- **条数偏少**：多数列表接口默认 `limit=10`，先确认是否只拿到第一页，按主文件「参数规则」的分页方式拉全量再下结论。
- **字段缺失**：以 `detail` 的 `outputSchema` 为准；未声明时按字段名规则推断，不要臆造字段。
- **切换组织后工具消失/变化**：可用工具由 API Key 与组织共同决定，切换组织后必须重新 `wepig tools` / `endpoints` 发现。
- **空结果 ≠ 接口失败**：`call` 成功但数据为空时，如实表述"该条件下查询无记录"，并建议调整日期范围或过滤条件；与报错分开表述。
