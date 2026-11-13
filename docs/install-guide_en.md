# wepig-skills — AI Agent Install Guide (International / GitHub source)

You are an AI coding assistant. Follow these steps to install wepig-skills (version 1.0.1) for the user.

> This guide uses the **GitHub upstream repository** (`github.com/wepigcn/wepig-skills`), which is also the install script default.
> Users in mainland China should use [install-guide.md](install-guide.md) instead (Gitee mirror `gitee.com/wepig/wepig-skills`).

## What is wepig-skills?

A collection of Skills that gives coding assistants (Claude Code, Cursor, Qoder, Gemini CLI, Codex CLI, OpenCode, etc.) access to MCP tools on the [Wepig Pig digital management platform](https://wepig.cn). Available capabilities depend on the API key, organization, and backend tools; they are not limited to queries.

## Step 1 — Confirm prerequisites

Ask the user:
1. Their operating system (macOS / Linux / Windows)
2. Which coding harness(es) they use (Claude Code, Cursor, Gemini CLI, Codex CLI, OpenCode, Antigravity, GitHub Copilot CLI — or "all available")

Do not ask for APPID/SECRET — after installation `wepig auth` handles browser authorization. If the user already has a personal API key, they can also export `WEPIG_API_KEY` manually.

## Step 2 — Run the install script (GitHub source)

The repository source is injected through environment variables. For the international/GitHub source the defaults already point at GitHub, so no override is required; set them explicitly only if you want to pin the source:

**macOS / Linux** — run this shell command (it is interactive; answer the prompts):

```bash
WEPIG_REPO_HOST=github.com WEPIG_REPO_OWNER=wepigcn \
  bash <(curl -fsSL https://raw.githubusercontent.com/wepigcn/wepig-skills/main/install.sh)
```

**Windows (PowerShell 7+)**:

```powershell
$env:WEPIG_REPO_HOST = "github.com"; $env:WEPIG_REPO_OWNER = "wepigcn"
irm https://raw.githubusercontent.com/wepigcn/wepig-skills/main/install.ps1 | iex
```

Environment variables understood by both install scripts:

| Variable | This guide | Default |
| --- | --- | --- |
| `WEPIG_REPO_HOST` | `github.com` | `github.com` |
| `WEPIG_REPO_OWNER` | `wepigcn` | `wepigcn` |
| `WEPIG_REPO_NAME` | `wepig-skills` (no need to set) | `wepig-skills` |
| `WEPIG_REPO_URL` | — (optional, overrides the clone URL entirely) | `https://github.com/wepigcn/wepig-skills.git` |

Notes:
- To use the Gitee mirror, set `WEPIG_REPO_HOST=gitee.com WEPIG_REPO_OWNER=wepig`.
- If the user already installed from one source, re-running the script does **not** switch sources — an existing clone is only `git pull`-ed, and the script warns when the origin differs. Switch with `git -C ~/.local/share/wepig-skills remote set-url origin <url>`.
- Codex CLI registers via `codex plugin marketplace add <https-url>`; Gitee URLs work there too.
- Gemini CLI / Antigravity officially take GitHub repos as extension sources; a Gitee source may fail (the script warns first).

The script will:
- Clone the repo to `~/.local/share/wepig-skills` (Linux/macOS) or `%LOCALAPPDATA%\wepig-skills` (Windows)
- Auto-detect installed harnesses and register the skill in each one
- Generate the `wepig` command
- Run a connectivity test to verify the setup

## Step 3 — Authorize

After installation, run browser authorization:

```bash
wepig auth
```

The command prints a verification URL and code and opens the browser; once the user approves, the personal API key is saved to `~/.config/wepig/env` (mode 600).

If the user already has a personal API key, the fallback is:

```bash
export WEPIG_API_KEY=your_api_key
```

## Step 4 — Select an organization

One key may access multiple organizations. List and persist a choice:

```bash
wepig orgs              # list organizations available to the key
wepig use COMPANY:123   # persist the current organization
```

When only one organization is available the CLI uses it automatically; with multiple organizations and no context it errors and asks for the commands above. Use `--org TYPE:ID` for a one-off override.

## Step 5 — Verify the install

```bash
wepig services
```

Expected output: a JSON list of services available in the current organization. If you see an error, check the env vars:

```bash
echo $WEPIG_API_KEY
wepig orgs
```

If `WEPIG_API_KEY` is empty, source the env file:

```bash
source ~/.config/wepig/env
```

Then re-run `wepig services`.

## Step 6 — Harness-specific verification

| Harness | How to verify |
| --- | --- |
| Claude Code | Run `/skills` — `wepig` should appear in the list |
| Cursor | Open a chat, type `@wepig` — it should autocomplete |
| Gemini CLI | Run `gemini extensions list` — `wepig` should be listed |
| Codex CLI | Run `/plugins` inside a session — `wepig` should be listed |
| OpenCode | Check `~/.config/opencode/opencode.json` — should contain a `file://...wepig-skills` plugin entry |

## Upgrading from the old version

This is a breaking upgrade: the old `APPID/SECRET`, `/ucenter/token`, `/open/mcp` and `open-wepig` naming are gone. Re-running the installer removes old commands, symlinks and environment variables, then authorizes again with `wepig auth`.

## Troubleshooting

- **`wepig: command not found`** — Your shell may not have sourced the new PATH. Run `source ~/.zshrc` (zsh) or `source ~/.bashrc` (bash), then retry.
- **401 / auth errors** — Re-run `wepig auth`, or verify `WEPIG_API_KEY` is valid.
- **"multiple organizations" error** — Run `wepig orgs`, then `wepig use TYPE:ID`, or pass `--org TYPE:ID` for a single call.
- **Skill not visible in harness** — Re-run the install script and select the specific harness, or follow the manual registration steps in the [README](https://github.com/wepigcn/wepig-skills#readme).
- **Clone fails / 404** — Confirm `WEPIG_REPO_HOST=github.com` and `WEPIG_REPO_OWNER=wepigcn`, and that the branch is `main`. If GitHub is unreachable, use the Gitee mirror guide instead ([install-guide.md](install-guide.md)).
- **Windows execution policy error** — Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` first.

## Uninstall

```bash
# macOS / Linux
bash install.sh uninstall

# Windows
powershell -ExecutionPolicy Bypass -File install.ps1 uninstall
```

---

Once installation is complete, tell the user:
> wepig-skills is installed. Run `wepig tools` to see what this API key and organization can do, then ask me to perform any supported Wepig operation.
