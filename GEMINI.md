# wepig

猪场养殖业务 MCP 工具扩展。支持的能力由 API Key、组织和后端工具决定。完整用法见 `skills/wepig/SKILL.md`。

首次使用执行 `wepig auth` 完成浏览器授权，个人 API Key 会保存到 `~/.config/wepig/env`。备选：手动设置环境变量 `WEPIG_API_KEY`。多组织用户用 `wepig orgs` 查看、`wepig use TYPE:ID` 切换。通过 `wepig` 命令调用（由 install.sh 安装到 PATH）。

## 工作流

按顺序执行，不要跳步直接 call：

```bash
# 1. 发现接口
wepig endpoints --keyword <keyword>

# 2. 查看参数与响应结构
wepig detail <endpoint_name>

# 3. 调用接口
wepig call <endpoint_name> key=value ...

# 4. 结果转述：不要直接粘贴原始 JSON；按用户问题组织结论/表格。
#    优先展示 *_name / *_desc / *_label；没有展示字段且需要定位记录时再展示 id/code/origin。
#    完整规则见 skills/wepig/SKILL.md「结果呈现」。
```
