# wepig-skills 安装、更新与卸载脚本 (Windows PowerShell)
# 用法：
#   powershell -ExecutionPolicy Bypass -File install.ps1              # 安装
#   powershell -ExecutionPolicy Bypass -File install.ps1 update        # 更新
#   powershell -ExecutionPolicy Bypass -File install.ps1 uninstall     # 卸载
#   powershell -ExecutionPolicy Bypass -File install.ps1 --help
#
# 一键安装（PowerShell 7+）：
#   irm https://raw.githubusercontent.com/wepigcn/wepig-skills/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

# ---------- 常量 ----------
# 仓库源可注入（国内镜像用 gitee，国际用 github）：
#   $env:WEPIG_REPO_HOST="gitee.com"; $env:WEPIG_REPO_OWNER="wepig"
# 也可整体覆盖 $env:WEPIG_REPO_URL。
$REPO_HOST   = if ($env:WEPIG_REPO_HOST)  { $env:WEPIG_REPO_HOST }  else { "github.com" }
$REPO_OWNER  = if ($env:WEPIG_REPO_OWNER) { $env:WEPIG_REPO_OWNER } else { "wepigcn" }
$REPO_NAME   = if ($env:WEPIG_REPO_NAME)  { $env:WEPIG_REPO_NAME }  else { "wepig-skills" }
$REPO_URL    = if ($env:WEPIG_REPO_URL)   { $env:WEPIG_REPO_URL }   else { "https://$REPO_HOST/$REPO_OWNER/$REPO_NAME.git" }
$MARKETPLACE_NAME = "wepig-skills"
$SKILL_NAME  = "wepig"
$CMD_NAME    = "wepig"
$LOCALAPPDATA = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $env:USERPROFILE "AppData\Local" }
$INSTALL_DIR = if ($env:WEPIG_INSTALL_DIR) { $env:WEPIG_INSTALL_DIR } else { Join-Path $LOCALAPPDATA "wepig-skills" }
$ENV_DIR     = Join-Path $env:USERPROFILE ".config\wepig"
$ENV_FILE    = Join-Path $ENV_DIR "env.ps1"
$SKILL_SRC   = Join-Path $INSTALL_DIR "skills\$SKILL_NAME"
$WEP_ABS     = Join-Path $INSTALL_DIR "bin\wepig.mjs"
$BINDIR      = Join-Path $env:USERPROFILE ".local\bin"

# 旧 open-wepig 安装位置（仅清理，绝不用于新版验证）
$LEGACY_INSTALL_DIR = Join-Path $LOCALAPPDATA "open-wepig-skills"
$LEGACY_ENV_DIR     = Join-Path $env:USERPROFILE ".config\open-wepig"
$LEGACY_DOTENV      = Join-Path $env:USERPROFILE ".open-wepig.env"
$LEGACY_CMD         = Join-Path $BINDIR "open-wepig-cli.cmd"

# 版本号唯一来源：仓库根目录 VERSION 文件
function Get-RepoVersion {
  $file = Join-Path $INSTALL_DIR "VERSION"
  if (Test-Path $file) {
    $value = (Get-Content $file -Raw).Trim()
    if ($value) { return $value }
  }
  return "unknown"
}

# 项目级安装参数（由参数解析填充）
$PROJECT_DIR = $null
$PROJECT_ENV_FILE = $null
$PROJECT_CONTEXT_FILE = $null

# 鉴权是否复用已有文件（$true=复用，$false=新授权/手动输入）
$script:AuthReused = $false
$script:ApiKey = $null
$script:LegacyFound = $false

# ---------- 输出辅助 ----------
function Write-Cyan($msg)  { Write-Host $msg -ForegroundColor Cyan }
function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Yellow($msg){ Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host $msg -ForegroundColor Red -ErrorAction Continue }

function Usage {
  Write-Host "用法: powershell -File install.ps1 [install|update|uninstall|--help] [--project [DIR]]"
  Write-Host "  install    交互式安装（默认）：设备授权 + 生成 wepig 命令 + 装 harness + 实测"
  Write-Host "  update     拉取最新并同步到各已安装 harness"
  Write-Host "  uninstall  卸载：删命令、链接、鉴权、profile 配置行（clone 目录可选）"
  Write-Host ""
  Write-Host "项目级安装："
  Write-Host "  powershell -File install.ps1 install --project                 # 安装到当前目录"
  Write-Host "  powershell -File install.ps1 install --project ./my-app        # 安装到指定项目"
  Write-Host "  powershell -File install.ps1 update --project ./my-app         # 更新项目级 harness"
  Write-Host "  powershell -File install.ps1 uninstall --project ./my-app      # 卸载项目级 harness"
  Write-Host ""
  Write-Host "说明：Claude Code / Cursor 支持项目级 skill；Copilot / Antigravity /"
  Write-Host "      Gemini / Codex / OpenCode 本质为全局插件，项目模式下仍会安装但全局生效。"
  Write-Host ""
  Write-Host "仓库源（默认 GitHub 官方仓库）可用环境变量注入："
  Write-Host "  WEPIG_REPO_HOST  默认 github.com，国内镜像用 gitee.com"
  Write-Host "  WEPIG_REPO_OWNER 默认 wepigcn，gitee 镜像为 wepig"
  Write-Host "  WEPIG_REPO_NAME  默认 wepig-skills"
  Write-Host "  WEPIG_REPO_URL   整体覆盖克隆地址"
  Write-Host "  WEPIG_INSTALL_DIR 覆盖安装目录（默认 %LOCALAPPDATA%\wepig-skills）"
}

# ---------- 基础检查 ----------
function Assert-Node {
  if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Err "未检测到 Node.js。wepig CLI 需要 Node >= 18，请先安装：https://nodejs.org/"
    exit 1
  }
}

function Get-TargetEnvFile {
  if ($PROJECT_DIR) { return $PROJECT_ENV_FILE }
  return $ENV_FILE
}

function Get-ContextFile {
  if ($PROJECT_DIR) { return $PROJECT_CONTEXT_FILE }
  return Join-Path $ENV_DIR "context"
}

function Sync-ContextEnv {
  $env:WEPIG_CONTEXT_FILE = Get-ContextFile
}

# ---------- 鉴权 ----------
function Ask-ManualApiKey {
  Write-Host "手动输入个人 API Key（可在 wepig 平台个人设置中创建）。"
  while ($true) {
    $secure = Read-Host "WEPIG_API_KEY（输入不回显）" -AsSecureString
    $key = [System.Net.NetworkCredential]::new("", $secure).Password
    if (-not [string]::IsNullOrWhiteSpace($key)) { $script:ApiKey = $key; return }
    Write-Err "WEPIG_API_KEY 不能为空"
  }
}

function Write-EnvFile($path, $key) {
  $dir = Split-Path $path -Parent
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $escaped = $key.Replace("'", "''")
  $lines = @(
    "# wepig 鉴权，由 install.ps1 生成",
    "`$env:WEPIG_API_KEY = '$escaped'"
  )
  if ($PROJECT_DIR -and ($path -eq $PROJECT_ENV_FILE)) {
    $ctx = $PROJECT_CONTEXT_FILE.Replace("'", "''")
    $lines += "`$env:WEPIG_CONTEXT_FILE = '$ctx'"
  }
  Set-Content -Path $path -Value ($lines -join "`n") -Encoding UTF8
  Write-Green "已写入 $path"
}

function Add-ProjectContextLine($path) {
  if (!$PROJECT_DIR -or !(Test-Path $path)) { return }
  $raw = Get-Content $path -Raw -ErrorAction SilentlyContinue
  if ($raw -and ($raw -match "WEPIG_CONTEXT_FILE")) { return }
  $ctx = $PROJECT_CONTEXT_FILE.Replace("'", "''")
  Add-Content -Path $path -Value "`$env:WEPIG_CONTEXT_FILE = '$ctx'"
}

function Import-EnvFile($path) {
  # 只加载新版 wepig env；旧 open-wepig 凭证不参与新版验证
  if (!(Test-Path $path)) { return $false }
  try { . $path } catch { return $false }
  return -not [string]::IsNullOrWhiteSpace($env:WEPIG_API_KEY)
}

function Use-BrowserAuth($target) {
  Write-Cyan "启动浏览器设备授权..."
  $dir = Split-Path $target -Parent
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  & node $WEP_ABS auth --file $target
  if (($LASTEXITCODE -eq 0) -and (Test-Path $target) -and (Import-EnvFile $target)) {
    Add-ProjectContextLine $target
    Write-Green "浏览器授权完成"
    return
  }
  Write-Err "浏览器授权未完成（超时、被拒绝或网络异常）。"
  $manual = Read-Host "改为手动输入 WEPIG_API_KEY？[Y/n]"
  if ($manual -match "^[Nn]$") {
    Write-Err "未获得 WEPIG_API_KEY，安装终止。"
    exit 1
  }
  Ask-ManualApiKey
  Write-EnvFile $target $script:ApiKey
  $env:WEPIG_API_KEY = $script:ApiKey
}

function Collect-Auth {
  $script:AuthReused = $false
  $target = Get-TargetEnvFile
  if (Test-Path $target) {
    $reuse = Read-Host "检测到 wepig 鉴权文件 $target，是否复用？[Y/n]"
    if ($reuse -notmatch "^[Nn]$") {
      if (Import-EnvFile $target) {
        Add-ProjectContextLine $target
        Write-Green "复用已有 WEPIG_API_KEY"
        $script:AuthReused = $true
        return
      }
      Write-Yellow "该文件未提供有效 WEPIG_API_KEY，需重新授权"
    }
  } elseif ((-not $PROJECT_DIR) -and (-not [string]::IsNullOrWhiteSpace($env:WEPIG_API_KEY))) {
    $reuse = Read-Host "检测到当前会话已设置 WEPIG_API_KEY，是否复用？[Y/n]"
    if ($reuse -notmatch "^[Nn]$") {
      Write-EnvFile $ENV_FILE $env:WEPIG_API_KEY
      Write-Green "复用当前会话 WEPIG_API_KEY"
      $script:AuthReused = $true
      return
    }
  }
  Use-BrowserAuth $target
}

# ---------- Profile ----------
function Ensure-Profile {
  $dir = Split-Path $PROFILE -Parent
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
}

function Update-ProfileLine($line) {
  Ensure-Profile
  $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
  if ($content -and $content.Contains($line)) { return }
  Add-Content -Path $PROFILE -Value "`n$line"
}

function Remove-ProfileLines($pattern) {
  if (!(Test-Path $PROFILE)) { return }
  $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
  if (!$content -or !(Select-String -InputObject $content -Pattern $pattern -Quiet)) { return }
  Copy-Item $PROFILE "$PROFILE.bak.wepig" -Force
  $lines = $content -split "`r?`n" | Where-Object { $_ -notmatch $pattern }
  Set-Content -Path $PROFILE -Value ($lines -join "`n") -NoNewline
  Write-Green "已清理 $PROFILE 中的旧配置行（备份 $PROFILE.bak.wepig）"
}

# ---------- 生成 wepig 命令 ----------
function Write-CLIWrapper {
  if (!(Test-Path $BINDIR)) { New-Item -ItemType Directory -Path $BINDIR -Force | Out-Null }
  $wrapper = "@echo off`r`nnode `"$WEP_ABS`" %*"
  $cmdPath = Join-Path $BINDIR "$CMD_NAME.cmd"
  Set-Content -Path $cmdPath -Value $wrapper -Encoding ASCII
  Write-Green "已生成命令 $cmdPath"
  $pathLine = '$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"  # wepig-skills'
  # 项目级安装不写全局 env source 行，避免引用不存在的全局 env.ps1
  if (-not $PROJECT_DIR) {
    $envLine = '. "$env:USERPROFILE\.config\wepig\env.ps1"  # wepig-skills'
    Update-ProfileLine $envLine
  }
  Update-ProfileLine $pathLine
}

# ---------- 仓库同步 ----------
function Sync-Repo {
  if (Test-Path (Join-Path $INSTALL_DIR ".git")) {
    $cur = git -C $INSTALL_DIR remote get-url origin 2>$null
    if ($cur -and ($cur -ne $REPO_URL)) {
      Write-Yellow "已有仓库来源为 ${cur}，与本次指定的 $REPO_URL 不同；仍从已有来源拉取"
      Write-Yellow "如需切换：git -C `"$INSTALL_DIR`" remote set-url origin $REPO_URL"
    }
    Write-Host "已存在仓库，拉取更新..."
    git -C $INSTALL_DIR pull --ff-only
  } elseif (Test-Path $INSTALL_DIR) {
    Write-Err "安装目录已存在但不是 git 仓库：$INSTALL_DIR"
    Write-Yellow "请移走该目录后重跑，或通过 WEPIG_INSTALL_DIR 指定其他目录。"
    exit 1
  } else {
    Write-Host "克隆仓库 $REPO_URL ..."
    git clone $REPO_URL $INSTALL_DIR
  }
  if (!(Test-Path $WEP_ABS)) {
    Write-Err "未找到 $WEP_ABS，仓库内容不是 wepig-skills。"
    Write-Yellow "请确认仓库地址与分支，或删除 $INSTALL_DIR 后重装。"
    exit 1
  }
}

# ---------- 组织初始化 ----------
function Initialize-Org {
  Write-Cyan "读取可访问组织..."
  $raw = & node $WEP_ABS orgs 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Err "读取组织失败："
    Write-Host ($raw | Out-String)
    exit 1
  }
  $data = ($raw | Out-String) | ConvertFrom-Json
  $orgs = @($data.orgs | Where-Object { $null -ne $_ })
  if ($orgs.Count -eq 0) {
    Write-Err "当前 API Key 没有可访问组织。"
    exit 1
  }
  if ($orgs.Count -eq 1) {
    $value = "$($orgs[0].org_type):$($orgs[0].org_id)"
    & node $WEP_ABS use $value | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Err "写入组织上下文失败：$value"; exit 1 }
    Write-Green "唯一组织 $value $($orgs[0].name)，已写入 $env:WEPIG_CONTEXT_FILE"
    return
  }

  Write-Host "可访问组织："
  for ($j = 0; $j -lt $orgs.Count; $j++) {
    Write-Host ("  {0}) {1}:{2}  {3}" -f ($j + 1), $orgs[$j].org_type, $orgs[$j].org_id, $orgs[$j].name)
  }
  Write-Host "提示：之后随时可用 wepig use TYPE:ID 切换组织。"
  $sel = Read-Host "选择组织（序号或 TYPE:ID）"
  if ([string]::IsNullOrWhiteSpace($sel)) { Write-Err "多组织账号必须明确选择组织。"; exit 1 }
  if ($sel -match "^\d+$") {
    $idx = [int]$sel - 1
    if (($idx -lt 0) -or ($idx -ge $orgs.Count)) { Write-Err "序号超出范围：$sel"; exit 1 }
    $value = "$($orgs[$idx].org_type):$($orgs[$idx].org_id)"
  } else {
    $value = $sel.Trim()
  }
  & node $WEP_ABS use $value | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Err "组织选择失败：$value"; exit 1 }
  Write-Green "已选择组织 $value"
}

# ---------- 实测 ----------
function Verify {
  Write-Cyan "验证鉴权与连通性..."
  $output = & node $WEP_ABS services 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-Green "鉴权与连通性正常"
    return
  }
  Write-Err "实测失败（API Key 无效、网络不通或网关未授权）："
  Write-Host ($output | Out-String)
  Write-Yellow "修正：编辑 $(Get-TargetEnvFile) 后重跑，或重新安装"
  exit 1
}

# ---------- 旧 open-wepig 清理 ----------
function Remove-PathSafe($path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return }
  if (!(Test-Path -LiteralPath $path)) { return }
  $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
  if ($item -and ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
    cmd /c rmdir "$path" 2>$null | Out-Null
  }
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Remove-OpenCodePluginEntry($predicate) {
  $cfg = Join-Path $env:USERPROFILE ".config\opencode\opencode.json"
  if (!(Test-Path $cfg)) { return }
  try {
    $json = Get-Content $cfg -Raw | ConvertFrom-Json
    if (!$json.plugin) { return }
    $before = @($json.plugin).Count
    $json.plugin = @($json.plugin | Where-Object { -not (& $predicate $_) })
    if (@($json.plugin).Count -ne $before) {
      $json | ConvertTo-Json -Depth 10 | Set-Content $cfg -Encoding UTF8
      Write-Green "OpenCode：已移除旧 plugin 引用"
      $script:LegacyFound = $true
    }
  } catch {
    Write-Yellow "OpenCode：$cfg 解析失败，请手动检查 plugin 数组"
  }
}

function Clean-LegacyInstall {
  Write-Cyan "清理旧 open-wepig 安装..."
  Remove-Item Env:OPEN_WEPIG_APPID,Env:OPEN_WEPIG_SECRET,Env:OPEN_WEPIG_TOKEN_URL -ErrorAction SilentlyContinue

  # 1) 旧命令
  if (Test-Path $LEGACY_CMD) {
    Remove-Item $LEGACY_CMD -Force -ErrorAction SilentlyContinue
    Write-Green "已删旧命令 $LEGACY_CMD"
    $script:LegacyFound = $true
  }

  # 2) 旧 skills junction
  $legacySkills = @(
    (Join-Path $env:USERPROFILE ".claude\skills\open-wepig"),
    (Join-Path $env:USERPROFILE ".cursor\skills\open-wepig")
  )
  if ($PROJECT_DIR) {
    $legacySkills += (Join-Path $PROJECT_DIR ".claude\skills\open-wepig")
    $legacySkills += (Join-Path $PROJECT_DIR ".cursor\skills\open-wepig")
  }
  foreach ($p in $legacySkills) {
    if (Test-Path -LiteralPath $p) {
      Remove-PathSafe $p
      Write-Green "已删旧 skills 链接 $p"
      $script:LegacyFound = $true
    }
  }

  # 3) 旧插件 / 扩展注册
  if (Get-Command claude -ErrorAction SilentlyContinue) {
    claude plugin uninstall "open-wepig@open-wepig-skills" 2>$null | Out-Null
    claude plugin marketplace remove "open-wepig-skills" 2>$null | Out-Null
  }
  if (Get-Command copilot -ErrorAction SilentlyContinue) {
    copilot plugin uninstall "open-wepig@open-wepig-skills" 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Green "Copilot CLI：已卸载旧插件"; $script:LegacyFound = $true }
    copilot plugin marketplace remove "open-wepig-skills" 2>$null | Out-Null
  }
  if (Get-Command agy -ErrorAction SilentlyContinue) {
    agy plugin uninstall open-wepig 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { agy plugin remove open-wepig 2>$null | Out-Null }
    Write-Green "Antigravity：已尝试卸载旧插件"
  }
  if (Get-Command gemini -ErrorAction SilentlyContinue) {
    gemini extensions remove open-wepig 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { gemini extensions uninstall open-wepig 2>$null | Out-Null }
    Write-Green "Gemini：已尝试卸载旧扩展"
  }
  if (Get-Command codex -ErrorAction SilentlyContinue) {
    codex plugin remove open-wepig 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { codex plugin uninstall open-wepig 2>$null | Out-Null }
    codex plugin marketplace remove "open-wepig-skills" 2>$null | Out-Null
    Write-Green "Codex：已尝试卸载旧插件"
  }
  Remove-OpenCodePluginEntry { param($entry) [string]$entry -match "open-wepig" }

  # 4) 旧配置 / 凭证 / 项目 env
  if (Test-Path $LEGACY_ENV_DIR) {
    Remove-PathSafe $LEGACY_ENV_DIR
    Write-Green "已删旧配置目录 $LEGACY_ENV_DIR"
    $script:LegacyFound = $true
  }
  if (Test-Path $LEGACY_DOTENV) {
    Remove-Item $LEGACY_DOTENV -Force -ErrorAction SilentlyContinue
    Write-Green "已删旧凭证文件 $LEGACY_DOTENV"
    $script:LegacyFound = $true
  }
  if ($PROJECT_DIR) {
    $oldProjectEnv = Join-Path $PROJECT_DIR ".open-wepig.env.ps1"
    if (Test-Path $oldProjectEnv) {
      Remove-Item $oldProjectEnv -Force -ErrorAction SilentlyContinue
      Write-Green "已删旧项目凭证 $oldProjectEnv"
      $script:LegacyFound = $true
    }
  }

  # 5) 旧 profile 配置行
  Remove-ProfileLines "open-wepig"

  # 6) 旧 token 缓存（旧 CLI 落盘在临时目录）
  $tmp = [System.IO.Path]::GetTempPath()
  Get-ChildItem -LiteralPath $tmp -Filter "open-wepig-token-*.json" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
    Write-Green "已删旧 token 缓存 $($_.FullName)"
    $script:LegacyFound = $true
  }

  # 7) 旧 clone：仅删除安装器管理的默认路径
  if (($LEGACY_INSTALL_DIR -ne $INSTALL_DIR) -and (Test-Path $LEGACY_INSTALL_DIR)) {
    Remove-Item -LiteralPath $LEGACY_INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    Write-Green "已删旧安装目录 $LEGACY_INSTALL_DIR"
    $script:LegacyFound = $true
  }

  if (!$script:LegacyFound) { Write-Host "未发现旧 open-wepig 残留。" }
}

# ---------- 各平台安装 ----------
function Link-Skill($targetDir) {
  $target = Join-Path $targetDir $SKILL_NAME
  $parent = Split-Path $target -Parent
  if (!(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  if (Test-Path $target) { cmd /c rmdir "$target" 2>$null | Out-Null; Remove-Item $target -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Junction -Path $target -Target $SKILL_SRC | Out-Null
  Write-Green "已链接 $target"
}

# 项目模式下，非文件系统 harness 本质全局生效，给出提示
function Global-HarnessWarning($name) {
  if ($PROJECT_DIR) {
    Write-Yellow "注意：$name 为全局插件/扩展，不局限于此项目"
  }
}

# Gemini / Antigravity 官方只以 GitHub 仓库为扩展源，非 GitHub 源可能失败
function Repo-SourceWarning($name) {
  if ($REPO_HOST -eq "github.com") { return }
  Write-Yellow "注意：$name 官方以 GitHub 仓库为扩展源，当前为 ${REPO_HOST}；失败时请改用 GitHub 源重跑"
}

function Install-Claude {
  if ($PROJECT_DIR) { Link-Skill (Join-Path $PROJECT_DIR ".claude\skills") }
  else { Link-Skill (Join-Path $env:USERPROFILE ".claude\skills") }
}
function Install-Cursor {
  if ($PROJECT_DIR) { Link-Skill (Join-Path $PROJECT_DIR ".cursor\skills") }
  else { Link-Skill (Join-Path $env:USERPROFILE ".cursor\skills") }
}

function Install-Copilot {
  Global-HarnessWarning "Copilot CLI"
  if (!(Get-Command copilot -ErrorAction SilentlyContinue)) {
    Write-Yellow "未检测到 copilot。装好后执行：copilot plugin marketplace add $REPO_OWNER/$REPO_NAME && copilot plugin install $SKILL_NAME@$MARKETPLACE_NAME"
    return
  }
  copilot plugin marketplace add "$REPO_OWNER/$REPO_NAME" 2>$null | Out-Null
  if (copilot plugin install "$SKILL_NAME@$MARKETPLACE_NAME") { Write-Green "Copilot CLI 插件已安装" }
  else { Write-Err "Copilot 安装失败，请手动排查" }
}

function Install-Antigravity {
  Global-HarnessWarning "Antigravity"
  Repo-SourceWarning "Antigravity"
  if (!(Get-Command agy -ErrorAction SilentlyContinue)) {
    Write-Yellow "未检测到 agy。装好后执行：agy plugin install $REPO_URL"; return
  }
  if (agy plugin install $REPO_URL) { Write-Green "Antigravity 插件已安装" }
  else { Write-Err "Antigravity 安装失败" }
}

function Install-Gemini {
  Global-HarnessWarning "Gemini CLI"
  Repo-SourceWarning "Gemini CLI"
  if (!(Get-Command gemini -ErrorAction SilentlyContinue)) {
    Write-Yellow "未检测到 gemini。装好后执行：gemini extensions install $REPO_URL"; return
  }
  if (gemini extensions install $REPO_URL) { Write-Green "Gemini 扩展已安装" }
  else { Write-Err "Gemini 安装失败，请手动执行：gemini extensions install $REPO_URL" }
}

function Install-Codex {
  Global-HarnessWarning "Codex CLI"
  if (!(Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Yellow "未检测到 codex。装好后执行：codex plugin marketplace add ${REPO_URL}，再在 /plugins 安装 $SKILL_NAME"; return
  }
  codex plugin marketplace add $REPO_URL 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { codex plugin marketplace add "$REPO_OWNER/$REPO_NAME" 2>$null | Out-Null }
  if ($LASTEXITCODE -eq 0) { Write-Green "Codex marketplace 已注册。请在 Codex CLI 的 /plugins 中安装 $SKILL_NAME" }
  else { Write-Err "Codex marketplace 注册失败，请手动执行：codex plugin marketplace add $REPO_URL" }
}

function Install-OpenCode {
  Global-HarnessWarning "OpenCode"
  $cfg = Join-Path $env:USERPROFILE ".config\opencode\opencode.json"
  $cfgDir = Split-Path $cfg -Parent
  if (!(Test-Path $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
  if (!(Test-Path $cfg)) { '{}' | Set-Content $cfg -Encoding UTF8 }
  try {
    $json = Get-Content $cfg -Raw | ConvertFrom-Json
    $plugin = "file://$INSTALL_DIR"
    $plugins = @($json.plugin | Where-Object { $null -ne $_ })
    if ($plugins -notcontains $plugin) {
      $plugins += $plugin
      $json | Add-Member -NotePropertyName plugin -NotePropertyValue $plugins -Force
      $json | ConvertTo-Json -Depth 10 | Set-Content $cfg -Encoding UTF8
      Write-Green "OpenCode：已写入 $plugin 到 $cfg"
    }
  } catch {
    Write-Yellow "解析 $cfg 失败，请手动在 plugin 数组加入 `"file://$INSTALL_DIR`""
  }
}

# ---------- 各平台更新 ----------
function Update-Claude {
  $base = if ($PROJECT_DIR) { $PROJECT_DIR } else { $env:USERPROFILE }
  $prefix = if ($PROJECT_DIR) { "项目级 " } else { "" }
  if (Test-Path (Join-Path $base ".claude\skills\$SKILL_NAME")) { Write-Green "Claude Code：${prefix}junction 随 repo pull 自动更新" }
}
function Update-Cursor {
  $base = if ($PROJECT_DIR) { $PROJECT_DIR } else { $env:USERPROFILE }
  $prefix = if ($PROJECT_DIR) { "项目级 " } else { "" }
  if (Test-Path (Join-Path $base ".cursor\skills\$SKILL_NAME")) { Write-Green "Cursor：${prefix}junction 随 repo pull 自动更新" }
}
function Update-Copilot {
  if (!(Get-Command copilot -ErrorAction SilentlyContinue)) { return }
  copilot plugin marketplace add "$REPO_OWNER/$REPO_NAME" 2>$null | Out-Null
  if (copilot plugin install "$SKILL_NAME@$MARKETPLACE_NAME" 2>$null) { Write-Green "Copilot CLI：已更新" }
}
function Update-Antigravity {
  if (!(Get-Command agy -ErrorAction SilentlyContinue)) { return }
  if (agy plugin install $REPO_URL 2>$null) { Write-Green "Antigravity：已更新" }
}
function Update-Gemini {
  if (!(Get-Command gemini -ErrorAction SilentlyContinue)) { return }
  if (gemini extensions update $SKILL_NAME 2>$null) { Write-Green "Gemini：已更新" }
}
function Update-Codex {
  if (!(Get-Command codex -ErrorAction SilentlyContinue)) { return }
  codex plugin marketplace upgrade 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { Write-Green "Codex：marketplace 已刷新" }
  else { codex plugin marketplace add $REPO_URL 2>$null | Out-Null }
}
function Update-OpenCode {
  $cfg = Join-Path $env:USERPROFILE ".config\opencode\opencode.json"
  if (Test-Path $cfg) {
    if ((Get-Content $cfg -Raw) -match [regex]::Escape("file://$INSTALL_DIR")) {
      Write-Green "OpenCode：file:// 引用随 repo pull 自动更新"
    }
  }
}

# ---------- 各平台卸载 ----------
function Uninstall-Claude {
  $base = if ($PROJECT_DIR) { $PROJECT_DIR } else { $env:USERPROFILE }
  $p = Join-Path $base ".claude\skills\$SKILL_NAME"
  if (Test-Path -LiteralPath $p) {
    Remove-PathSafe $p
    $prefix = if ($PROJECT_DIR) { "项目级 " } else { "" }
    Write-Green "Claude Code：已删${prefix}链接"
  }
}
function Uninstall-Cursor {
  $base = if ($PROJECT_DIR) { $PROJECT_DIR } else { $env:USERPROFILE }
  $p = Join-Path $base ".cursor\skills\$SKILL_NAME"
  if (Test-Path -LiteralPath $p) {
    Remove-PathSafe $p
    $prefix = if ($PROJECT_DIR) { "项目级 " } else { "" }
    Write-Green "Cursor：已删${prefix}链接"
  }
}

function Uninstall-Copilot {
  if (!(Get-Command copilot -ErrorAction SilentlyContinue)) { return }
  copilot plugin uninstall "$SKILL_NAME@$MARKETPLACE_NAME" 2>$null | Out-Null
  copilot plugin marketplace remove $MARKETPLACE_NAME 2>$null | Out-Null
  Write-Green "Copilot CLI：已尝试卸载"
}
function Uninstall-Antigravity {
  if (!(Get-Command agy -ErrorAction SilentlyContinue)) { return }
  agy plugin uninstall $SKILL_NAME 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { agy plugin remove $SKILL_NAME 2>$null | Out-Null }
  Write-Green "Antigravity：已尝试卸载"
}
function Uninstall-Gemini {
  if (!(Get-Command gemini -ErrorAction SilentlyContinue)) { return }
  gemini extensions remove $SKILL_NAME 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { gemini extensions uninstall $SKILL_NAME 2>$null | Out-Null }
  Write-Green "Gemini：已尝试卸载"
}
function Uninstall-Codex {
  if (!(Get-Command codex -ErrorAction SilentlyContinue)) { return }
  codex plugin remove $SKILL_NAME 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { codex plugin uninstall $SKILL_NAME 2>$null | Out-Null }
  codex plugin marketplace remove $MARKETPLACE_NAME 2>$null | Out-Null
  Write-Green "Codex：已尝试卸载"
}
function Uninstall-OpenCode {
  $installDir = $INSTALL_DIR
  Remove-OpenCodePluginEntry { param($entry) ([string]$entry).Contains($installDir) }
}

# ---------- 交互式安装范围选择（命令行已传 --project 时跳过） ----------
function Ask-InstallScope {
  if ($PROJECT_DIR) { return }
  Write-Host "选择安装范围："
  Write-Host "  1) 用户空间（默认）"
  Write-Host "  2) 项目本地"
  $scope = Read-Host "选择 [1]"
  if (!$scope) { $scope = "1" }
  if ($scope -eq "2") {
    $proj = Read-Host "项目目录 [.]"
    if (!$proj) { $proj = "." }
    if (!(Test-Path $proj)) { New-Item -ItemType Directory -Path $proj -Force | Out-Null }
    $script:PROJECT_DIR = (Resolve-Path $proj).Path
    $script:PROJECT_ENV_FILE = Join-Path $script:PROJECT_DIR ".wepig.env.ps1"
    $script:PROJECT_CONTEXT_FILE = Join-Path $script:PROJECT_DIR ".wepig.context"
    Write-Green "将安装到项目：$script:PROJECT_DIR"
  }
}

# ---------- 安装流程 ----------
function Do-Install {
  Write-Cyan "wepig-skills 安装程序"
  Assert-Node
  Ask-InstallScope
  Sync-Repo
  Collect-Auth
  Sync-ContextEnv
  Initialize-Org
  Verify

  # 新版本验证通过后再清理旧 open-wepig，避免留下不可用的新装
  Clean-LegacyInstall
  Write-CLIWrapper

  Write-Host ""
  Write-Host "选择目标 harness（可多选，逗号分隔；输入 a 全选）："
  Write-Host "  1) Claude Code    2) Cursor    3) GitHub Copilot CLI"
  Write-Host "  4) Antigravity    5) Gemini CLI    6) Codex CLI    7) OpenCode"
  $choice = Read-Host "选择 [1]"
  if (!$choice) { $choice = "1" }
  if ($choice -match "^[aA]$") { $choice = "1,2,3,4,5,6,7" }
  foreach ($s in ($choice -split ",")) {
    switch ($s.Trim()) {
      "1" { Install-Claude }
      "2" { Install-Cursor }
      "3" { Install-Copilot }
      "4" { Install-Antigravity }
      "5" { Install-Gemini }
      "6" { Install-Codex }
      "7" { Install-OpenCode }
      default { Write-Err "忽略未知选项: $s" }
    }
  }
  Write-Host ""
  Write-Green "wepig-skills $(Get-RepoVersion) 安装完成。"
  if ($PROJECT_DIR) {
    Write-Host "当前终端执行以下命令立即生效：. $PROJECT_ENV_FILE"
    Write-Host "（项目级鉴权与组织上下文优先于全局 $ENV_FILE）"
  } else {
    Write-Host "当前终端执行以下命令立即生效：. $ENV_FILE"
    Write-Host "或新开终端后即可用 $CMD_NAME 命令（如 $CMD_NAME services）。"
  }
}

# ---------- 更新流程 ----------
function Do-Update {
  Write-Cyan "wepig-skills 更新"
  Assert-Node
  Sync-Repo
  Collect-Auth
  Sync-ContextEnv
  Initialize-Org
  Verify

  Clean-LegacyInstall
  Write-CLIWrapper
  Write-Host ""
  Update-Claude; Update-Cursor; Update-Copilot; Update-Antigravity
  Update-Gemini; Update-Codex; Update-OpenCode
  Write-Host ""
  Write-Green "wepig-skills $(Get-RepoVersion) 更新完成。"
  if ($PROJECT_DIR) {
    Write-Host "当前终端执行：. $PROJECT_ENV_FILE  刷新环境"
  } else {
    Write-Host "如需刷新环境，当前终端执行：. $ENV_FILE"
  }
}

# ---------- 卸载流程 ----------
function Do-Uninstall {
  Write-Cyan "wepig-skills 卸载"
  if ($PROJECT_DIR) {
    Write-Host "将删除项目级内容："
    Write-Host "  - $(Join-Path $PROJECT_DIR ".claude\skills\$SKILL_NAME")"
    Write-Host "  - $(Join-Path $PROJECT_DIR ".cursor\skills\$SKILL_NAME")"
    Write-Host "  - $PROJECT_ENV_FILE"
    Write-Host "  - $PROJECT_CONTEXT_FILE"
    Write-Yellow "注意：Copilot / Antigravity / Gemini / Codex / OpenCode 为全局插件，将执行全局卸载"
  } else {
    Write-Host "将删除："
    Write-Host "  - 命令 $(Join-Path $BINDIR "$CMD_NAME.cmd")"
    Write-Host "  - 各 harness 的链接 / plugin 注册"
    Write-Host "  - 鉴权与组织配置 $ENV_DIR"
    Write-Host "  - PowerShell profile 里的 wepig-skills 行（保留 .bak 备份）"
  }
  $confirm = Read-Host "确认卸载？[y/N]"
  if ($confirm -notmatch "^[Yy]$") { Write-Yellow "已取消"; return }

  if ($PROJECT_DIR) {
    Uninstall-Claude; Uninstall-Cursor
    if (Test-Path $PROJECT_ENV_FILE) { Remove-Item $PROJECT_ENV_FILE -Force; Write-Green "已删 $PROJECT_ENV_FILE" }
    if (Test-Path $PROJECT_CONTEXT_FILE) { Remove-Item $PROJECT_CONTEXT_FILE -Force; Write-Green "已删 $PROJECT_CONTEXT_FILE" }
    Uninstall-Copilot; Uninstall-Antigravity; Uninstall-Gemini; Uninstall-Codex; Uninstall-OpenCode
  } else {
    $cmdPath = Join-Path $BINDIR "$CMD_NAME.cmd"
    if (Test-Path $cmdPath) { Remove-Item $cmdPath -Force; Write-Green "已删命令 $cmdPath" }
    Uninstall-Claude; Uninstall-Cursor; Uninstall-Copilot; Uninstall-Antigravity
    Uninstall-Gemini; Uninstall-Codex; Uninstall-OpenCode
    if (Test-Path $ENV_DIR) {
      Remove-PathSafe $ENV_DIR
      Write-Green "已删 $ENV_DIR"
    }
    Remove-ProfileLines "wepig-skills|\.config\\wepig"

    Write-Host ""
    $delrepo = Read-Host "是否删除 clone 目录 $INSTALL_DIR？[y/N]"
    if ($delrepo -match "^[Yy]$") {
      Remove-Item $INSTALL_DIR -Recurse -Force; Write-Green "已删 $INSTALL_DIR"
    } else {
      Write-Yellow "保留 clone 目录 $INSTALL_DIR（可手动删除）"
    }
  }
  Write-Host ""
  Write-Green "卸载完成。"
}

# ---------- 主入口 ----------
$script:ACTION = $null
$script:PROJECT_DIR = $null
$i = 0
while ($i -lt $args.Count) {
  $arg = $args[$i]
  if ($arg -eq "--project") {
    $i++
    if ($i -lt $args.Count) {
      $next = $args[$i]
      if ($next -in @("install","update","uninstall","--help","-h") -or $next.StartsWith("-")) {
        $script:PROJECT_DIR = (Get-Location).Path
      } else {
        $script:PROJECT_DIR = $next
        $i++
      }
    } else {
      $script:PROJECT_DIR = (Get-Location).Path
    }
  } elseif ($arg -in @("-h","--help")) {
    $script:ACTION = "--help"; $i++
  } elseif ($arg -in @("install","update","uninstall")) {
    $script:ACTION = $arg; $i++
  } else {
    Write-Err "未知参数: $arg"; Usage; exit 1
  }
}
if (-not $script:ACTION) { $script:ACTION = "install" }
if ($script:PROJECT_DIR) {
  if (!(Test-Path $script:PROJECT_DIR)) { New-Item -ItemType Directory -Path $script:PROJECT_DIR -Force | Out-Null }
  $script:PROJECT_DIR = (Resolve-Path $script:PROJECT_DIR).Path
  $script:PROJECT_ENV_FILE = Join-Path $script:PROJECT_DIR ".wepig.env.ps1"
  $script:PROJECT_CONTEXT_FILE = Join-Path $script:PROJECT_DIR ".wepig.context"
}

switch ($script:ACTION) {
  "install"   { Do-Install }
  "update"    { Do-Update }
  "uninstall" { Do-Uninstall }
  "-h"        { Usage }
  "--help"    { Usage }
  default     { Write-Err "未知参数: $script:ACTION"; Usage }
}
