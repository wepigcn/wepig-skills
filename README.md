# wepig-skills

中文 | [English](README_en.md)

给编码助手接入[微猪生猪数字化管理平台](https://wepig.cn) MCP 工具的 [Skills](https://docs.claude.com/en/docs/claude-code/skills) 集合。支持的能力由当前 API Key、组织和后端工具共同决定，不限于数据查询。当前版本 **1.0.1**。

## 安装

> 中文版统一使用 **Gitee 国内源**（`gitee.com/wepig/wepig-skills`）。

### 方式一：一键脚本（推荐）

**让 AI 助手帮你安装** — 将以下提示词粘贴到 Claude Code、Cursor、Qoder 或任意 AI 编程助手中：

```
请按照以下安装指南，帮我安装 wepig-skills：
https://gitee.com/wepig/wepig-skills/raw/main/docs/install-guide.md
```

AI 助手会读取安装指南、向你确认目标平台，然后自动完成整个安装流程。

**或者自己运行：**

**macOS / Linux：**

```bash
WEPIG_REPO_HOST=gitee.com WEPIG_REPO_OWNER=wepig \
  bash <(curl -fsSL https://gitee.com/wepig/wepig-skills/raw/main/install.sh)
```

**Windows（PowerShell 7+）：**

```powershell
$env:WEPIG_REPO_HOST = "gitee.com"; $env:WEPIG_REPO_OWNER = "wepig"
irm https://gitee.com/wepig/wepig-skills/raw/main/install.ps1 | iex
```

以上命令通过环境变量指定 Gitee 仓库源。可注入的变量：

| 变量 | 说明 | 默认值 |
| --- | --- | --- |
| `WEPIG_REPO_HOST` | 仓库主机 | `github.com` |
| `WEPIG_REPO_OWNER` | 仓库所有者 | `wepigcn` |
| `WEPIG_REPO_NAME` | 仓库名 | `wepig-skills` |
| `WEPIG_REPO_URL` | 整体覆盖克隆地址 | `https://<host>/<owner>/<name>.git` |

> 已从其他源装过的用户重跑上面的命令**不会自动切换来源**（脚本只对已有 clone 执行 `git pull`，并会提示来源不一致）。要切换：`git -C ~/.local/share/wepig-skills remote set-url origin https://gitee.com/wepig/wepig-skills.git`。
> 另：Gemini CLI / Antigravity 官方以 GitHub 仓库为扩展源，用 Gitee 源安装可能失败（脚本会先给出提示）。

### 方式二：Claude Code plugin marketplace

```text
/plugin marketplace add https://gitee.com/wepig/wepig-skills.git
/plugin install wepig@wepig-skills
```

> marketplace 安装只让 Claude Code 识别 skill，**仍需再跑一次方式一**安装 `wepig` 命令。
> 仓库内的 `.claude-plugin/marketplace.json` 插件地址指向 GitHub 官方仓库；国内网络拉取失败时请改用方式一。

### 方式三：手动 clone

**macOS / Linux：**

```bash
git clone https://gitee.com/wepig/wepig-skills.git ~/.local/share/wepig-skills
# 授权（写入 ~/.config/wepig/env）
node ~/.local/share/wepig-skills/scripts/wepig.mjs auth
# 或手动配置个人 API Key
export WEPIG_API_KEY=你的个人APIKey
# 直接用绝对路径调用，或跑一次 bash install.sh 生成 wepig 命令
node ~/.local/share/wepig-skills/scripts/wepig.mjs services
```

**Windows：**

```powershell
git clone https://gitee.com/wepig/wepig-skills.git $env:LOCALAPPDATA\wepig-skills
# 授权
node $env:LOCALAPPDATA\wepig-skills\scripts\wepig.mjs auth
# 或手动配置个人 API Key
$env:WEPIG_API_KEY = "你的个人APIKey"
# 直接用绝对路径调用，或跑一次 install.ps1 生成 wepig 命令
node $env:LOCALAPPDATA\wepig-skills\scripts\wepig.mjs services
```

## 鉴权与组织

默认用浏览器设备授权，无需手工抄写凭证：

```bash
wepig auth        # 浏览器确认授权码后，个人 API Key 保存到 ~/.config/wepig/env
```

备选：已有个人 API Key 时手动配置环境变量 `WEPIG_API_KEY`。

一个 Key 可访问多个组织。执行 `tools`、`services`、`endpoints`、`detail`、`call` 前，必须先通过 `backstage_user_orgs`（由 `wepig orgs` 调用）并选择唯一组织：

```bash
wepig orgs              # 列出当前 Key 可访问的组织
wepig use COMPANY:123   # 持久切换当前组织
wepig --org COMPANY:123 call <endpoint_name> ...   # 单次覆盖，不改持久上下文
```

组织优先级：`--org` > `WEPIG_ORG` > `WEPIG_CONTEXT_FILE`（默认 `~/.config/wepig/context`）> 当前 Key 唯一可访问的组织 > 报错。仓库根目录的 `.wepig.env` / `.wepig.env.ps1` 是项目级凭证文件，已加入 `.gitignore`。

## 命令

| 命令 | 作用 |
| --- | --- |
| `wepig auth` | 浏览器授权并保存个人 API Key |
| `wepig orgs` | 列出当前 Key 可访问的组织 |
| `wepig use TYPE:ID` | 持久切换当前组织 |
| `wepig tools` | 列出当前 Key 和组织实际支持的 MCP 工具 |
| `wepig services` | 列出 service 及健康/接口数 |
| `wepig endpoints --keyword <k>` | 发现接口 |
| `wepig detail <name>` | 查看参数与响应 schema |
| `wepig call <name> key=value ...` | 调用接口 |

## 各平台自动安装/更新命令

`install.sh` / `install.ps1` 按所选 harness 自动执行；命令缺失时跳过并打印手动命令。安装完成后所有平台统一用 `wepig` 命令。

| Harness | 自动安装命令 | 自动更新 |
| --- | --- | --- |
| **Claude Code** | symlink/junction → `~/.claude/skills` | `git pull` 后自动 |
| **Cursor** | symlink/junction → `~/.cursor/skills` | `git pull` 后自动 |
| **GitHub Copilot CLI** | `copilot plugin marketplace add` + `install` | 重跑 install |
| **Antigravity** | `agy plugin install <repo>` | 重跑即更新 |
| **Gemini CLI** | `gemini extensions install <repo>`（已含 `gemini-extension.json`） | `gemini extensions update wepig` |
| **Codex CLI** | `codex plugin marketplace add <repo-or-https-url>`（已含 `.agents/plugins/marketplace.json`），再 `/plugins` 安装 | `codex plugin marketplace upgrade` |
| **OpenCode** | 写入 `~/.config/opencode/opencode.json` 的 `file://` plugin（macOS/Linux 需 `jq`） | `git pull` 后自动 |

## 从旧版升级

本版为不兼容升级（1.0.0）：旧的 `APPID/SECRET` 凭证、`/ucenter/token` 换 token、`/open/mcp` 地址、`open-wepig` 命名全部废弃；旧 `open-wepig-cli` 命令与 `~/.config/open-wepig/`、`~/.local/share/open-wepig-skills/` 不再使用。重跑安装脚本会清理旧命令、旧 symlink 和旧环境变量，并改用 `wepig auth` 重新授权。

## 卸载

**macOS / Linux：**

```bash
bash install.sh uninstall
```

**Windows：**

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 uninstall
```

> 各平台 plugin 卸载子命令（agy / gemini / codex）以兼容方式尝试，若该 CLI 的卸载子命令名不同，可能需手动确认。
