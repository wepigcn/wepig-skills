#!/usr/bin/env bash
# wepig-skills 安装、更新与卸载脚本
# 用法：
#   bash install.sh              # 安装（交互鉴权 + 生成 wepig 命令 + 选 harness + 实测）
#   bash install.sh update        # 更新（拉取最新 + 各平台同步 + 刷新 wepig 命令）
#   bash install.sh uninstall     # 卸载（删命令、symlink、鉴权、shell 配置行；clone 目录可选）
#   bash install.sh --help

set -euo pipefail

# 仓库源可注入（国内镜像用 gitee，国际用 github）：
#   WEPIG_REPO_HOST=gitee.com WEPIG_REPO_OWNER=wepig bash install.sh
# 也可整体覆盖 WEPIG_REPO_URL。
REPO_HOST="${WEPIG_REPO_HOST:-github.com}"
REPO_OWNER="${WEPIG_REPO_OWNER:-wepigcn}"
REPO_NAME="${WEPIG_REPO_NAME:-wepig-skills}"
REPO_URL="${WEPIG_REPO_URL:-https://$REPO_HOST/$REPO_OWNER/$REPO_NAME.git}"
MARKETPLACE_NAME="wepig-skills"
SKILL_NAME="wepig"          # skill / plugin / 扩展名
CMD_NAME="wepig"        # 生成的 PATH 命令名
INSTALL_DIR="${WEPIG_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/wepig-skills}"
ENV_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/wepig"
ENV_FILE="$ENV_DIR/env"
SKILL_SRC="$INSTALL_DIR/skills/$SKILL_NAME"
WES_ABS="$INSTALL_DIR/scripts/wepig.mjs"
BINDIR="$HOME/.local/bin"

# 项目级安装参数（由参数解析填充）
PROJECT_DIR=""
PROJECT_ENV_FILE=""

# 鉴权是否复用已有文件（1=复用，0=新输入/未复用）
AUTH_REUSED=0

cyan()   { printf '\033[36m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
err()    { printf '\033[31m%s\033[0m\n' "$*" >&2; }

# 交互读取一行：curl|bash 下脚本 stdin 被管道占用，直接 read 会读到脚本后续行甚至卡死，
# 因此固定从真实终端 /dev/tty 读取（不替换 fd0，不影响 bash 继续解析脚本）；
# 其余用法同 read，透传 -r/-p/-s 等参数与变量名。
read_tty() {
  if [[ -e /dev/tty ]]; then
    read "$@" </dev/tty
  else
    read "$@"
  fi
}

usage() {
  cat <<EOF
用法: bash install.sh [install|update|uninstall|--help] [--project [DIR]]
  install    交互式安装（默认）：鉴权 + 生成 wepig 命令 + 装 harness + 实测
  update     拉取最新并同步到各已安装 harness
  uninstall  卸载：删命令、symlink、鉴权、shell 配置行（clone 目录可选）

项目级安装：
  bash install.sh install --project              # 安装到当前目录
  bash install.sh install --project ./my-app     # 安装到指定项目
  bash install.sh update --project ./my-app      # 更新项目级 harness
  bash install.sh uninstall --project ./my-app   # 卸载项目级 harness

说明：Claude Code / Cursor 支持项目级 skill；Copilot / Antigravity /
      Gemini / Codex / OpenCode 本质为全局插件，项目模式下仍会安装但全局生效。

仓库源（默认 GitHub 官方仓库）可用环境变量注入：
  WEPIG_REPO_HOST  默认 github.com，国内镜像用 gitee.com
  WEPIG_REPO_OWNER 默认 wepigcn，gitee 镜像为 wepig
  WEPIG_REPO_NAME  默认 wepig-skills
  WEPIG_REPO_URL   整体覆盖克隆地址
例：WEPIG_REPO_HOST=gitee.com WEPIG_REPO_OWNER=wepig bash install.sh
EOF
}

# ---------- 鉴权 ----------
target_env_file() {
  if [[ -n "$PROJECT_DIR" ]]; then printf '%s' "$PROJECT_ENV_FILE"; else printf '%s' "$ENV_FILE"; fi
}

target_context_file() {
  if [[ -n "$PROJECT_DIR" ]]; then printf '%s' "$PROJECT_DIR/.wepig.context"; else printf '%s' "$ENV_DIR/context"; fi
}

load_env() {
  local file; file="$(target_env_file)"
  set -a; source "$file"; set +a
  if [[ -n "$PROJECT_DIR" ]]; then export WEPIG_CONTEXT_FILE="$PROJECT_DIR/.wepig.context"; fi
}

write_manual_env() {
  local file; file="$(target_env_file)"
  mkdir -p "$(dirname "$file")"; chmod 700 "$(dirname "$file")"
  {
    printf '# wepig 鉴权，由 install.sh 生成\n'
    printf 'export WEPIG_API_KEY=%q\n' "$WEPIG_API_KEY"
    if [[ -n "$PROJECT_DIR" ]]; then printf 'export WEPIG_CONTEXT_FILE=%q\n' "$PROJECT_DIR/.wepig.context"; fi
  } > "$file"
  chmod 600 "$file"
}

collect_auth() {
  AUTH_REUSED=0
  local file; file="$(target_env_file)"
  if [[ -f "$file" ]]; then
    read_tty -rp "检测到新版鉴权文件，是否复用？[Y/n] " reuse
    if [[ ! "$reuse" =~ ^[Nn]$ ]]; then
      load_env
      if [[ -n "${WEPIG_API_KEY:-}" ]]; then AUTH_REUSED=1; return; fi
      yellow "鉴权文件没有 WEPIG_API_KEY，将重新授权"
    fi
  fi

  echo "选择鉴权方式："
  echo "  1) 浏览器授权（默认）"
  echo "  2) 手动输入个人 API Key"
  read_tty -rp "选择 [1]: " method
  if [[ "${method:-1}" == "2" ]]; then
    read_tty -rsp "WEPIG_API_KEY（输入不回显）: " WEPIG_API_KEY; echo
    while [[ -z "${WEPIG_API_KEY//[[:space:]]/}" ]]; do
      err "API Key 不能为空"; read_tty -rsp "WEPIG_API_KEY: " WEPIG_API_KEY; echo
    done
    export WEPIG_API_KEY
    write_manual_env
  else
    node "$WES_ABS" auth --file "$file"
    load_env
  fi
  if [[ -n "$PROJECT_DIR" ]] && ! grep -qF 'WEPIG_CONTEXT_FILE' "$file"; then
    printf 'export WEPIG_CONTEXT_FILE=%q\n' "$PROJECT_DIR/.wepig.context" >> "$file"
  fi
  green "鉴权已配置：$file"
}

ensure_env_path() {
  if ! grep -qF '# wepig-skills PATH' "$ENV_FILE" 2>/dev/null; then
    cat >> "$ENV_FILE" <<'EOF'

# wepig-skills PATH
WEPIG_BINDIR="$HOME/.local/bin"
case ":$PATH:" in
  *":$WEPIG_BINDIR:"*) ;;
  *) export PATH="$WEPIG_BINDIR:$PATH" ;;
esac
unset WEPIG_BINDIR
EOF
  fi
}

configure_shell() {
  if [[ -z "$PROJECT_DIR" ]]; then
    ensure_env_path
    local src_line='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/wepig/env" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/wepig/env"  # wepig-skills'
    local rc
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
      touch "$rc"
      grep -qF 'wepig/env' "$rc" 2>/dev/null || printf '\n%s\n' "$src_line" >> "$rc"
    done
  fi
}

# ---------- 生成 wepig PATH 命令 ----------
write_wepig_wrapper() {
  mkdir -p "$BINDIR"
  cat > "$BINDIR/$CMD_NAME" <<EOF
#!/usr/bin/env bash
# 由 wepig-skills install.sh 生成
exec node "$WES_ABS" "\$@"
EOF
  chmod +x "$BINDIR/$CMD_NAME"
}

# ---------- 仓库同步 ----------
# 版本号唯一来源：仓库根目录 VERSION 文件
repo_version() {
  local v=""
  [[ -f "$INSTALL_DIR/VERSION" ]] && v="$(tr -d '[:space:]' < "$INSTALL_DIR/VERSION" 2>/dev/null || true)"
  printf '%s' "${v:-unknown}"
}

sync_repo() {
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    local cur; cur="$(git -C "$INSTALL_DIR" remote get-url origin 2>/dev/null || true)"
    if [[ -n "$cur" && "$cur" != "$REPO_URL" ]]; then
      yellow "已有仓库来源为 ${cur}，与本次指定的 $REPO_URL 不同；仍从已有来源拉取"
      yellow "如需切换：git -C \"$INSTALL_DIR\" remote set-url origin $REPO_URL"
    fi
    echo "已存在仓库，拉取更新..."; git -C "$INSTALL_DIR" pull --ff-only
  else
    echo "克隆仓库 $REPO_URL ..."; git clone "$REPO_URL" "$INSTALL_DIR"
  fi
}

# ---------- 各平台安装 ----------
link_skill() { mkdir -p "$1"; ln -sfn "$SKILL_SRC" "$1/$SKILL_NAME"; green "已链接 $1/$SKILL_NAME"; }

# 项目模式下，非文件系统 harness 本质全局生效，给出提示
global_harness_warning() {
  if [[ -n "$PROJECT_DIR" ]]; then
    yellow "注意：$1 为全局插件/扩展，不局限于此项目"
  fi
}

# Gemini / Antigravity 官方只以 GitHub 仓库为扩展源，非 GitHub 源可能失败
repo_source_warning() {
  [[ "$REPO_HOST" == "github.com" ]] && return 0
  yellow "注意：$1 官方以 GitHub 仓库为扩展源，当前为 ${REPO_HOST}；失败时请改用 GitHub 源重跑"
}

install_claude() {
  if [[ -n "$PROJECT_DIR" ]]; then
    link_skill "$PROJECT_DIR/.claude/skills"
  else
    link_skill "$HOME/.claude/skills"
  fi
}
install_cursor() {
  if [[ -n "$PROJECT_DIR" ]]; then
    link_skill "$PROJECT_DIR/.cursor/skills"
  else
    link_skill "$HOME/.cursor/skills"
  fi
}

install_copilot() {
  global_harness_warning "Copilot CLI"
  if ! command -v copilot >/dev/null 2>&1; then
    yellow "未检测到 copilot。装好后执行：copilot plugin marketplace add $REPO_OWNER/$REPO_NAME && copilot plugin install $SKILL_NAME@$MARKETPLACE_NAME"; return
  fi
  copilot plugin marketplace add "$REPO_OWNER/$REPO_NAME" || true
  if copilot plugin install "$SKILL_NAME@$MARKETPLACE_NAME"; then green "Copilot CLI 插件已安装"
  else err "Copilot 安装失败，请手动排查"; fi
}

install_antigravity() {
  global_harness_warning "Antigravity"
  repo_source_warning "Antigravity"
  if ! command -v agy >/dev/null 2>&1; then
    yellow "未检测到 agy。装好后执行：agy plugin install $REPO_URL"; return
  fi
  if agy plugin install "$REPO_URL"; then green "Antigravity 插件已安装"
  else err "Antigravity 安装失败"; fi
}

install_gemini() {
  global_harness_warning "Gemini CLI"
  repo_source_warning "Gemini CLI"
  if ! command -v gemini >/dev/null 2>&1; then
    yellow "未检测到 gemini。装好后执行：gemini extensions install $REPO_URL"; return
  fi
  if gemini extensions install "$REPO_URL"; then green "Gemini 扩展已安装"
  else err "Gemini 安装失败，请手动执行：gemini extensions install $REPO_URL"; fi
}

install_codex() {
  global_harness_warning "Codex CLI"
  if ! command -v codex >/dev/null 2>&1; then
    yellow "未检测到 codex。装好后执行：codex plugin marketplace add ${REPO_URL}，再在 /plugins 安装 wepig"; return
  fi
  if codex plugin marketplace add "$REPO_URL" >/dev/null 2>&1 || codex plugin marketplace add "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1; then
    green "Codex marketplace 已注册。请在 Codex CLI 的 /plugins 中安装 wepig"
  else
    err "Codex marketplace 注册失败，请手动执行：codex plugin marketplace add $REPO_URL"
  fi
}

install_opencode() {
  global_harness_warning "OpenCode"
  local cfg="$HOME/.config/opencode/opencode.json"
  mkdir -p "$(dirname "$cfg")"
  [[ -s "$cfg" ]] || echo '{}' > "$cfg"
  if command -v jq >/dev/null 2>&1; then
    local tmp; tmp="$(mktemp)"
    if jq --arg p "file://$INSTALL_DIR" '.plugin = ((.plugin // []) | if index($p) then . else . + [$p] end)' "$cfg" > "$tmp"; then
      mv "$tmp" "$cfg"; green "OpenCode：已写入 file://$INSTALL_DIR 到 $cfg"
    else
      rm -f "$tmp"; yellow "jq 解析 $cfg 失败，请手动在 plugin 数组加入 \"file://$INSTALL_DIR\""
    fi
  else
    yellow "无 jq，请在 $cfg 的 plugin 数组手动加入 \"file://$INSTALL_DIR\""
  fi
}

# ---------- 各平台更新 ----------
update_claude() {
  if [[ -n "$PROJECT_DIR" ]]; then
    [[ -e "$PROJECT_DIR/.claude/skills/$SKILL_NAME" ]] && green "Claude Code：项目级 symlink 随 repo pull 自动更新" || true
  else
    [[ -e "$HOME/.claude/skills/$SKILL_NAME" ]] && green "Claude Code：symlink 随 repo pull 自动更新" || true
  fi
}
update_cursor() {
  if [[ -n "$PROJECT_DIR" ]]; then
    [[ -e "$PROJECT_DIR/.cursor/skills/$SKILL_NAME" ]] && green "Cursor：项目级 symlink 随 repo pull 自动更新" || true
  else
    [[ -e "$HOME/.cursor/skills/$SKILL_NAME" ]] && green "Cursor：symlink 随 repo pull 自动更新" || true
  fi
}

update_copilot() {
  command -v copilot >/dev/null 2>&1 || return 0
  copilot plugin marketplace add "$REPO_OWNER/$REPO_NAME" || true
  copilot plugin install "$SKILL_NAME@$MARKETPLACE_NAME" >/dev/null 2>&1 && green "Copilot CLI：已更新" || true
}

update_antigravity() {
  command -v agy >/dev/null 2>&1 || return 0
  agy plugin install "$REPO_URL" >/dev/null 2>&1 && green "Antigravity：已更新" || true
}

update_gemini() {
  command -v gemini >/dev/null 2>&1 || return 0
  gemini extensions update "$SKILL_NAME" >/dev/null 2>&1 && green "Gemini：已更新" || true
}

update_codex() {
  command -v codex >/dev/null 2>&1 || return 0
  if codex plugin marketplace upgrade >/dev/null 2>&1; then
    green "Codex：marketplace 已刷新"
  else
    codex plugin marketplace add "$REPO_URL" >/dev/null 2>&1 || true
  fi
}

update_opencode() {
  grep -qF "file://$INSTALL_DIR" "$HOME/.config/opencode/opencode.json" 2>/dev/null && green "OpenCode：file:// 引用随 repo pull 自动更新" || true
}

# ---------- 各平台卸载 ----------
uninstall_claude() {
  if [[ -n "$PROJECT_DIR" ]]; then
    rm -f "$PROJECT_DIR/.claude/skills/$SKILL_NAME" 2>/dev/null && green "Claude Code：已删项目级 symlink" || true
  else
    rm -f "$HOME/.claude/skills/$SKILL_NAME" 2>/dev/null && green "Claude Code：已删 symlink" || true
  fi
}
uninstall_cursor() {
  if [[ -n "$PROJECT_DIR" ]]; then
    rm -f "$PROJECT_DIR/.cursor/skills/$SKILL_NAME" 2>/dev/null && green "Cursor：已删项目级 symlink" || true
  else
    rm -f "$HOME/.cursor/skills/$SKILL_NAME" 2>/dev/null && green "Cursor：已删 symlink" || true
  fi
}

uninstall_copilot() {
  command -v copilot >/dev/null 2>&1 || return 0
  copilot plugin uninstall "$SKILL_NAME@$MARKETPLACE_NAME" >/dev/null 2>&1 && green "Copilot CLI：已卸载" || true
}

uninstall_antigravity() {
  command -v agy >/dev/null 2>&1 || return 0
  { agy plugin uninstall "$SKILL_NAME" || agy plugin remove "$SKILL_NAME"; } >/dev/null 2>&1 || true
  green "Antigravity：已尝试卸载"
}

uninstall_gemini() {
  command -v gemini >/dev/null 2>&1 || return 0
  { gemini extensions remove "$SKILL_NAME" || gemini extensions uninstall "$SKILL_NAME"; } >/dev/null 2>&1 || true
  green "Gemini：已尝试卸载"
}

uninstall_codex() {
  command -v codex >/dev/null 2>&1 || return 0
  codex plugin remove "$SKILL_NAME" >/dev/null 2>&1 || codex plugin uninstall "$SKILL_NAME" >/dev/null 2>&1 || true
  codex plugin marketplace remove "$MARKETPLACE_NAME" >/dev/null 2>&1 || true
  green "Codex：已尝试卸载"
}

uninstall_opencode() {
  local cfg="$HOME/.config/opencode/opencode.json"
  [[ -f "$cfg" ]] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    yellow "无 jq，请手动从 $cfg 的 plugin 数组移除 \"file://$INSTALL_DIR\""; return 0
  fi
  local tmp; tmp="$(mktemp)"
  if jq --arg p "file://$INSTALL_DIR" '.plugin = ((.plugin // []) | map(select(. != $p)))' "$cfg" > "$tmp"; then
    mv "$tmp" "$cfg"; green "OpenCode：已从 plugin 数组移除"
  else
    rm -f "$tmp"; yellow "OpenCode：$cfg 解析失败，请手动移除"
  fi
}

clean_rc() {
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    grep -qF '# wepig-skills' "$rc" || continue
    cp "$rc" "$rc.bak.wepig"
    if grep -vF '# wepig-skills' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"; then
      green "已清理 ${rc}（备份 $rc.bak.wepig）"
    else
      rm -f "$rc.tmp"; yellow "$rc 清理失败，保留原文件"
    fi
  done
}

# ---------- 组织初始化 ----------
ensure_org() {
  local orgs_json current selected count
  orgs_json="$(node "$WES_ABS" orgs)" || return 1
  current=""
  [[ -f "$(target_context_file)" ]] && current="$(tr -d '[:space:]' < "$(target_context_file)")"
  if [[ -n "$current" ]] && node -e 'const o=JSON.parse(process.argv[1]);process.exit(o.orgs.some(x=>`${x.org_type}:${x.org_id}`===process.argv[2])?0:1)' "$orgs_json" "$current"; then
    return 0
  fi
  count="$(node -e 'const o=JSON.parse(process.argv[1]);process.stdout.write(String(o.orgs.length))' "$orgs_json")"
  if [[ "$count" == "0" ]]; then err "当前 API Key 没有可访问组织"; return 1; fi
  if [[ "$count" == "1" ]]; then
    selected="$(node -e 'const o=JSON.parse(process.argv[1]).orgs[0];process.stdout.write(`${o.org_type}:${o.org_id}`)' "$orgs_json")"
  else
    node -e 'JSON.parse(process.argv[1]).orgs.forEach(o=>console.error(`${o.org_type}:${o.org_id}\t${o.name||""}`))' "$orgs_json" >&2
    read_tty -rp "选择组织 TYPE:ID: " selected
  fi
  node "$WES_ABS" use "$selected"
}

# ---------- 旧版清理 ----------
cleanup_legacy() {
  unset OPEN_WEPIG_APPID OPEN_WEPIG_SECRET OPEN_WEPIG_TOKEN_URL
  rm -f "$BINDIR/open-wepig-cli" "$HOME/.open-wepig.env"
  rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/open-wepig"
  if [[ -n "$PROJECT_DIR" ]]; then
    rm -f "$PROJECT_DIR/.open-wepig.env" "$PROJECT_DIR/.claude/skills/open-wepig" "$PROJECT_DIR/.cursor/skills/open-wepig"
  fi
  rm -f "$HOME/.claude/skills/open-wepig" "$HOME/.cursor/skills/open-wepig"
  if command -v claude >/dev/null 2>&1; then
    claude plugin uninstall open-wepig@open-wepig-skills >/dev/null 2>&1 || true
    claude plugin marketplace remove open-wepig-skills >/dev/null 2>&1 || true
  fi
  if command -v copilot >/dev/null 2>&1; then copilot plugin uninstall open-wepig@open-wepig-skills >/dev/null 2>&1 || true; fi
  if command -v agy >/dev/null 2>&1; then agy plugin uninstall open-wepig >/dev/null 2>&1 || agy plugin remove open-wepig >/dev/null 2>&1 || true; fi
  if command -v gemini >/dev/null 2>&1; then gemini extensions remove open-wepig >/dev/null 2>&1 || gemini extensions uninstall open-wepig >/dev/null 2>&1 || true; fi
  if command -v codex >/dev/null 2>&1; then
    codex plugin remove open-wepig >/dev/null 2>&1 || codex plugin uninstall open-wepig >/dev/null 2>&1 || true
    codex plugin marketplace remove open-wepig-skills >/dev/null 2>&1 || true
  fi
  local old_repo="${XDG_DATA_HOME:-$HOME/.local/share}/open-wepig-skills"
  local cfg="$HOME/.config/opencode/opencode.json"
  if command -v jq >/dev/null 2>&1 && [[ -f "$cfg" ]]; then
    local tmp; tmp="$(mktemp)"
    if jq --arg p "file://$old_repo" '.plugin = ((.plugin // []) | map(select(. != $p)))' "$cfg" > "$tmp"; then mv "$tmp" "$cfg"; else rm -f "$tmp"; fi
  fi
  local rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" ]] || continue
    if grep -qE 'open-wepig-skills|\.open-wepig\.env|open-wepig/env' "$rc"; then
      cp "$rc" "$rc.bak.open-wepig"
      grep -vE 'open-wepig-skills|\.open-wepig\.env|open-wepig/env' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc" || rm -f "$rc.tmp"
    fi
  done
  find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'open-wepig-token-*.json' -type f -delete 2>/dev/null || true
  if [[ "$old_repo" != "$INSTALL_DIR" ]]; then rm -rf "$old_repo"; fi
  green "旧版 open-wepig 已清理"
}

# ---------- 实测 ----------
verify() {
  cyan "验证鉴权、组织上下文与连通性..."
  local log; log="$(mktemp -t wepig-test)"
  if ! command -v node >/dev/null 2>&1; then
    err "未检测到 node，安装需要 Node >= 18"
    rm -f "$log" 2>/dev/null || true
    return 1
  fi
  if ensure_org && node "$WES_ABS" services >"$log" 2>&1; then
    green "鉴权、组织与连通性正常"
    rm -f "$log" 2>/dev/null || true
    return 0
  fi
  err "实测失败（API Key、组织权限、网络或网关异常）："
  cat "$log" 2>/dev/null || true
  yellow "修正：编辑 $(target_env_file) 后重跑，或重新安装"
  rm -f "$log" 2>/dev/null || true
  return 1
}

# 交互式安装范围选择（命令行已传 --project 时跳过）
ask_install_scope() {
  if [[ -n "$PROJECT_DIR" ]]; then
    return
  fi
  echo "选择安装范围："
  echo "  1) 用户空间（默认）"
  echo "  2) 项目本地"
  read_tty -rp "选择 [1]: " scope
  scope="${scope:-1}"
  if [[ "$scope" == "2" ]]; then
    read_tty -rp "项目目录 [.]： " proj
    proj="${proj:-.}"
    mkdir -p "$proj" || { err "无法创建项目目录: $proj"; exit 1; }
    PROJECT_DIR="$(cd "$proj" && pwd)" || { err "无法进入项目目录: $proj"; exit 1; }
    PROJECT_ENV_FILE="$PROJECT_DIR/.wepig.env"
    green "将安装到项目：$PROJECT_DIR"
  fi
}

# ---------- 安装流程 ----------
do_install() {
  cyan "wepig-skills 安装程序"
  ask_install_scope
  sync_repo
  collect_auth
  verify || exit 1
  configure_shell
  cleanup_legacy
  write_wepig_wrapper
  echo
  echo "选择目标 harness（可多选，逗号分隔；输入 a 全选）："
  echo "  1) Claude Code    2) Cursor    3) GitHub Copilot CLI"
  echo "  4) Antigravity    5) Gemini CLI    6) Codex CLI    7) OpenCode"
  read_tty -rp "选择 [1]: " choice
  choice="${choice:-1}"
  [[ "$choice" == "a" || "$choice" == "A" ]] && choice="1,2,3,4,5,6,7"
  IFS=',' read -ra SEL <<< "$choice"
  for s in "${SEL[@]}"; do
    case "${s//[[:space:]]/}" in
      1) install_claude ;; 2) install_cursor ;; 3) install_copilot ;;
      4) install_antigravity ;; 5) install_gemini ;; 6) install_codex ;;
      7) install_opencode ;; *) err "忽略未知选项: $s" ;;
    esac
  done
  echo; green "wepig-skills $(repo_version) 安装完成。"
  if [[ -n "$PROJECT_DIR" ]]; then
    echo "当前终端执行以下命令立即生效：source ${PROJECT_ENV_FILE}"
    echo "（项目级鉴权优先于全局 ~/.config/wepig/env）"
  else
    echo "当前终端执行以下命令立即生效：source ${ENV_FILE}"
  fi
}

# ---------- 更新流程 ----------
do_update() {
  cyan "wepig-skills 更新"
  sync_repo
  collect_auth
  verify || exit 1
  configure_shell
  cleanup_legacy
  write_wepig_wrapper
  echo
  update_claude; update_cursor; update_copilot; update_antigravity
  update_gemini; update_codex; update_opencode
  echo; green "wepig-skills $(repo_version) 更新完成。"
  if [[ -n "$PROJECT_DIR" ]]; then
    echo "当前终端执行：source ${PROJECT_ENV_FILE}  刷新环境"
  else
    echo "如鉴权文件已迁移，当前终端执行：source ${ENV_FILE}  刷新环境"
  fi
}

# ---------- 卸载流程 ----------
do_uninstall() {
  cyan "wepig-skills 卸载"
  if [[ -n "$PROJECT_DIR" ]]; then
    echo "将删除项目级内容："
    echo "  - $PROJECT_DIR/.claude/skills/$SKILL_NAME"
    echo "  - $PROJECT_DIR/.cursor/skills/$SKILL_NAME"
    echo "  - $PROJECT_ENV_FILE"
    yellow "注意：Copilot / Antigravity / Gemini / Codex / OpenCode 为全局插件，将执行全局卸载"
  else
    echo "将删除："
    echo "  - 命令 $BINDIR/$CMD_NAME"
    echo "  - 各 harness 的 symlink / plugin 注册"
    echo "  - 鉴权文件 $ENV_FILE"
    echo "  - shell 配置里的 wepig-skills 行（~/.zshrc、~/.bashrc，保留 .bak 备份）"
  fi
  read_tty -rp "确认卸载？[y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then yellow "已取消"; return; fi

  if [[ -n "$PROJECT_DIR" ]]; then
    uninstall_claude; uninstall_cursor
    rm -f "$PROJECT_ENV_FILE" 2>/dev/null && green "已删 $PROJECT_ENV_FILE" || true
    uninstall_copilot; uninstall_antigravity; uninstall_gemini; uninstall_codex; uninstall_opencode
  else
    rm -f "$BINDIR/$CMD_NAME" 2>/dev/null && green "已删命令 $BINDIR/$CMD_NAME" || true
    uninstall_claude; uninstall_cursor; uninstall_copilot; uninstall_antigravity
    uninstall_gemini; uninstall_codex; uninstall_opencode
    rm -f "$ENV_FILE" 2>/dev/null && green "已删 $ENV_FILE" || true
    rm -rf "$ENV_DIR"
    clean_rc

    echo
    read_tty -rp "是否删除 clone 目录 ${INSTALL_DIR}？[y/N] " delrepo
    if [[ "$delrepo" =~ ^[Yy]$ ]]; then
      rm -rf "$INSTALL_DIR" && green "已删 $INSTALL_DIR"
    else
      yellow "保留 clone 目录 ${INSTALL_DIR}（可手动 rm -rf 删除）"
    fi
  fi
  echo; green "卸载完成。"
}

# ---------- 参数解析 ----------
parse_args() {
  ACTION=""
  PROJECT_DIR=""
  local args=("$@")
  local i=0
  while [[ $i -lt ${#args[@]} ]]; do
    local arg="${args[$i]}"
    case "$arg" in
      --project)
        i=$((i+1))
        if [[ $i -lt ${#args[@]} ]]; then
          local next="${args[$i]}"
          if [[ "$next" == install || "$next" == update || "$next" == uninstall || "$next" == -h || "$next" == --help || "$next" == -* ]]; then
            PROJECT_DIR="."
          else
            PROJECT_DIR="$next"
            i=$((i+1))
          fi
        else
          PROJECT_DIR="."
        fi
        ;;
      -h|--help) ACTION="--help"; i=$((i+1)) ;;
      install|update|uninstall) ACTION="$arg"; i=$((i+1)) ;;
      *) err "未知参数: $arg"; usage; exit 1 ;;
    esac
  done
  [[ -z "$ACTION" ]] && ACTION="install"
  if [[ -n "$PROJECT_DIR" ]]; then
    mkdir -p "$PROJECT_DIR" || { err "无法创建项目目录: $PROJECT_DIR"; exit 1; }
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)" || { err "无法进入项目目录: $PROJECT_DIR"; exit 1; }
    PROJECT_ENV_FILE="$PROJECT_DIR/.wepig.env"
  fi
}

parse_args "$@"

case "$ACTION" in
  install) do_install ;;
  update) do_update ;;
  uninstall) do_uninstall ;;
  -h|--help) usage ;;
  *) err "未知参数: $ACTION"; usage; exit 1 ;;
esac
