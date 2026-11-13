# wepig-skills

[中文](README.md) | English

A collection of [Skills](https://docs.claude.com/en/docs/claude-code/skills) that gives coding assistants access to MCP tools on the [Wepig Pig digital management platform](https://wepig.cn). Capabilities are determined by the API key, selected organization, and available backend tools—not limited to queries. Current version: **1.1.0**.

## Installation

> The default source is the **GitHub upstream repository** (`github.com/wepigcn/wepig-skills`). Users in mainland China can switch to the **Gitee mirror** (`gitee.com/wepig/wepig-skills`) with the variables below.

### Option 1: One-liner (recommended)

**Let your AI agent install it** — paste this prompt into Claude Code, Cursor, Qoder, or any AI coding agent:

```
Please install wepig-skills by following the instructions here:
https://raw.githubusercontent.com/wepigcn/wepig-skills/main/docs/install-guide_en.md
```

The agent will read the install guide, confirm your target harness(es), and complete the full installation for you.

**Or run it yourself:**

**macOS / Linux:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wepigcn/wepig-skills/main/install.sh)
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/wepigcn/wepig-skills/main/install.ps1 | iex
```

For the Gitee mirror:

```bash
WEPIG_REPO_HOST=gitee.com WEPIG_REPO_OWNER=wepig \
  bash <(curl -fsSL https://gitee.com/wepig/wepig-skills/raw/main/install.sh)
```

```powershell
$env:WEPIG_REPO_HOST = "gitee.com"; $env:WEPIG_REPO_OWNER = "wepig"
irm https://gitee.com/wepig/wepig-skills/raw/main/install.ps1 | iex
```

The repository source is injected via environment variables; the defaults below already target the GitHub upstream:

| Variable | Meaning | Default |
| --- | --- | --- |
| `WEPIG_REPO_HOST` | repository host | `github.com` |
| `WEPIG_REPO_OWNER` | repository owner | `wepigcn` |
| `WEPIG_REPO_NAME` | repository name | `wepig-skills` |
| `WEPIG_REPO_URL` | overrides the whole clone URL | `https://<host>/<owner>/<name>.git` |

### Option 2: Claude Code plugin marketplace

```text
/plugin marketplace add wepigcn/wepig-skills
/plugin install wepig@wepig-skills
```

> The marketplace install only lets Claude Code recognize the skill. You still need to run Option 1 to install the `wepig` command.

### Option 3: Manual clone

**macOS / Linux:**

```bash
git clone https://github.com/wepigcn/wepig-skills.git ~/.local/share/wepig-skills
# Authorize (writes ~/.config/wepig/env)
node ~/.local/share/wepig-skills/scripts/wepig.mjs auth
# Or configure a personal API key manually
export WEPIG_API_KEY=your_api_key
# Call directly, or run bash install.sh to generate the wepig command
node ~/.local/share/wepig-skills/scripts/wepig.mjs services
```

**Windows:**

```powershell
git clone https://github.com/wepigcn/wepig-skills.git $env:LOCALAPPDATA\wepig-skills
# Authorize
node $env:LOCALAPPDATA\wepig-skills\scripts\wepig.mjs auth
# Or configure a personal API key manually
$env:WEPIG_API_KEY = "your_api_key"
# Call directly, or run install.ps1 to generate the wepig command
node $env:LOCALAPPDATA\wepig-skills\scripts\wepig.mjs services
```

## Authentication and organizations

Browser-based device authorization is the default; no manual credential copying:

```bash
wepig auth        # confirm the code in the browser; the personal API key is saved to ~/.config/wepig/env
```

Fallback: export an existing personal API key as `WEPIG_API_KEY`.

One key can access multiple organizations. Before `tools`, `services`, `endpoints`, `detail`, or `call`, select exactly one organization through `backstage_user_orgs` (invoked by `wepig orgs`). Every MCP request then includes `user_org_type/user_org_id`; the visible tools depend on both the API key and selected organization. Rediscover tools after switching organizations:

```bash
wepig orgs              # list organizations available to the key
wepig use COMPANY:123   # persist the current organization
wepig --org COMPANY:123 call <endpoint_name> ...   # one-off override
```

Resolution order: `--org` > `WEPIG_ORG` > `WEPIG_CONTEXT_FILE` (default `~/.config/wepig/context`) > the single organization available to the key > error. The repo-root `.wepig.env` / `.wepig.env.ps1` project credential files are git-ignored.

## Commands

| Command | Purpose |
| --- | --- |
| `wepig auth` | Browser authorization, saves the personal API key |
| `wepig orgs` | List organizations available to the key |
| `wepig use TYPE:ID` | Persist the current organization |
| `wepig tools` | List MCP tools available to the current key and organization |
| `wepig services` | List services with health/endpoint counts |
| `wepig endpoints --keyword <k>` | Discover endpoints |
| `wepig detail <name>` | Show parameter and response schema |
| `wepig call <name> key=value ...` | Call an endpoint |

## Harness support

`install.sh` / `install.ps1` auto-installs to selected harnesses; missing CLIs are skipped with manual instructions. After installation, all platforms use the `wepig` command.

| Harness | Install command | Auto-update |
| --- | --- | --- |
| **Claude Code** | symlink/junction → `~/.claude/skills` | after `git pull` |
| **Cursor** | symlink/junction → `~/.cursor/skills` | after `git pull` |
| **GitHub Copilot CLI** | `copilot plugin marketplace add` + `install` | re-run install |
| **Antigravity** | `agy plugin install <repo>` | re-run to update |
| **Gemini CLI** | `gemini extensions install <repo>` (includes `gemini-extension.json`) | `gemini extensions update wepig` |
| **Codex CLI** | `codex plugin marketplace add <repo-or-https-url>` (includes `.agents/plugins/marketplace.json`), then install via `/plugins` | `codex plugin marketplace upgrade` |
| **OpenCode** | writes `file://` plugin to `~/.config/opencode/opencode.json` (requires `jq` on macOS/Linux) | after `git pull` |

## Upgrading from the old version

This is a breaking 1.0.0 upgrade: the old `APPID/SECRET` credentials, `/ucenter/token` token exchange, `/open/mcp` endpoint, and `open-wepig` naming are gone; the old `open-wepig-cli` command plus `~/.config/open-wepig/` and `~/.local/share/open-wepig-skills/` are no longer used. Re-running the installer removes old commands, symlinks and environment variables, then authorizes again through `wepig auth`.

## Uninstall

**macOS / Linux:**

```bash
bash install.sh uninstall
```

**Windows:**

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 uninstall
```

> Plugin uninstall sub-commands (agy / gemini / codex) are attempted in compatibility mode; if the CLI uses a different sub-command name, manual confirmation may be needed.
