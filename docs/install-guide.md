# wepig-skills — AI Agent 安装指南（国内 / Gitee 源）

你是 AI 编程助手。按以下步骤为用户安装 wepig-skills（版本 1.0.1）。

> 本文使用 **Gitee 镜像源**（`gitee.com/wepig/wepig-skills`），适合国内网络环境。
> 安装脚本默认源是 GitHub 官方仓库（`github.com/wepigcn/wepig-skills`）；海外网络请改用 [install-guide_en.md](install-guide_en.md)。

## wepig-skills 是什么？

一组 Skills，为编码助手（Claude Code、Cursor、Qoder、Gemini CLI、Codex CLI、OpenCode 等）接入[微猪生猪数字化管理平台](https://wepig.cn)的 MCP 工具。具体能力由 API Key、组织和后端工具决定，不限于查询。

## Step 1 — 确认前提

先向用户确认：
1. 操作系统（macOS / Linux / Windows）
2. 使用哪些编码 harness（Claude Code、Cursor、Gemini CLI、Codex CLI、OpenCode、Antigravity、GitHub Copilot CLI —— 或「全部可用的」）

不需要预先索要 APPID/SECRET：安装后用 `wepig auth` 走浏览器授权即可。若用户已有个人 API Key，也可以手动配置 `WEPIG_API_KEY`。

## Step 2 — 运行安装脚本（注入 Gitee 源）

安装脚本的仓库源由环境变量注入，国内直接指定 Gitee 镜像：

**macOS / Linux** — 运行以下命令（交互式，按提示作答）：

```bash
WEPIG_REPO_HOST=gitee.com WEPIG_REPO_OWNER=wepig \
  bash <(curl -fsSL https://gitee.com/wepig/wepig-skills/raw/main/install.sh)
```

**Windows（PowerShell 7+）**：

```powershell
$env:WEPIG_REPO_HOST = "gitee.com"; $env:WEPIG_REPO_OWNER = "wepig"
irm https://gitee.com/wepig/wepig-skills/raw/main/install.ps1 | iex
```

不设置变量即使用默认 GitHub 源（`github.com/wepigcn/wepig-skills`）。变量含义：

| 变量 | 本文取值 | 默认值（GitHub） |
| --- | --- | --- |
| `WEPIG_REPO_HOST` | `gitee.com` | `github.com` |
| `WEPIG_REPO_OWNER` | `wepig` | `wepigcn` |
| `WEPIG_REPO_NAME` | `wepig-skills`（无需设置） | `wepig-skills` |
| `WEPIG_REPO_URL` | —（可选，整体覆盖克隆地址） | `https://<host>/<owner>/<name>.git` |

注意事项：
- 用户之前若已用其他源装过，重跑上面的命令**不会自动切换来源**（脚本对已有 clone 只做 `git pull`，并会提示来源不一致）。切换方式：`git -C ~/.local/share/wepig-skills remote set-url origin https://gitee.com/wepig/wepig-skills.git`。
- Gemini CLI / Antigravity 官方以 GitHub 仓库为扩展源，Gitee 源可能装不上；脚本会先警告，失败时请按脚本提示处理。
- Codex CLI 用 `codex plugin marketplace add <https-url>` 注册，Gitee 地址可用。

脚本会：
- 把仓库克隆到 `~/.local/share/wepig-skills`（Linux/macOS）或 `%LOCALAPPDATA%\wepig-skills`（Windows）
- 自动探测已安装的 harness，并在各自位置注册 skill
- 生成 `wepig` 命令
- 跑一次连通性实测

## Step 3 — 授权

安装完成后执行浏览器授权：

```bash
wepig auth
```

命令会打印授权地址和授权码，并在浏览器打开确认页；用户在浏览器确认后，个人 API Key 自动保存到 `~/.config/wepig/env`（权限 600）。

若用户已有个人 API Key，备选方式是手动配置环境变量：

```bash
export WEPIG_API_KEY=你的个人APIKey
```

## Step 4 — 选择组织

一个 Key 可访问多个组织。查看并持久选择：

```bash
wepig orgs              # 列出当前 Key 可访问的组织
wepig use COMPANY:123   # 持久切换当前组织
```

只有一个可访问组织时 CLI 会自动使用；多个组织且未选择时会报错并提示先执行上述命令。单次调用可用 `--org TYPE:ID` 覆盖，不改变持久上下文。

## Step 5 — 验证安装

```bash
wepig services
```

预期输出：当前组织可用的 service JSON 列表。报错时先确认环境变量已生效：

```bash
echo $WEPIG_API_KEY
wepig orgs
```

为空则先载入 env 文件：

```bash
source ~/.config/wepig/env
```

再重跑 `wepig services`。

## Step 6 — 各 harness 验证

| Harness | 验证方式 |
| --- | --- |
| Claude Code | 运行 `/skills` — 列表中应出现 `wepig` |
| Cursor | 打开对话输入 `@wepig` — 应可自动补全 |
| Gemini CLI | 运行 `gemini extensions list` — 应列出 `wepig` |
| Codex CLI | 会话内运行 `/plugins` — 应列出 `wepig` |
| OpenCode | 检查 `~/.config/opencode/opencode.json` — 应含 `file://...wepig-skills` 插件项 |

## 从旧版升级

本版为不兼容升级：旧的 `APPID/SECRET`、`/ucenter/token`、`/open/mcp` 与 `open-wepig` 命名全部废弃。重跑安装脚本会清理旧命令、旧 symlink、旧环境变量，然后用 `wepig auth` 重新授权。

## 常见问题

- **`wepig: command not found`** — 当前 shell 未加载新 PATH。执行 `source ~/.zshrc`（zsh）或 `source ~/.bashrc`（bash）后重试。
- **401 / 鉴权失败** — 重新执行 `wepig auth`，或核对 `WEPIG_API_KEY` 是否有效。
- **提示存在多个可访问组织** — 先 `wepig orgs`，再 `wepig use TYPE:ID`，或单次加 `--org TYPE:ID`。
- **harness 中看不到 skill** — 重跑安装脚本并单选该 harness，或参考 [README](https://gitee.com/wepig/wepig-skills#readme) 的手动注册步骤。
- **Gitee 拉取失败 / 404** — 确认 `WEPIG_REPO_HOST=gitee.com`、`WEPIG_REPO_OWNER=wepig` 且分支为 `main`，并检查 https://gitee.com/wepig/wepig-skills 是否可以访问。
- **Windows 执行策略报错** — 先运行 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`。

## 卸载

```bash
# macOS / Linux
bash install.sh uninstall

# Windows
powershell -ExecutionPolicy Bypass -File install.ps1 uninstall
```

---

安装完成后，告知用户：
> wepig-skills 已安装。先运行 `wepig tools` 查看当前 API Key 和组织支持的能力，然后即可让我执行任意受支持的微猪业务操作。
