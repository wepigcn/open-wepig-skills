# open-wepig-skills 安装、更新与卸载脚本 (Windows PowerShell)
# 用法：
#   powershell -ExecutionPolicy Bypass -File install.ps1              # 安装
#   powershell -ExecutionPolicy Bypass -File install.ps1 update        # 更新
#   powershell -ExecutionPolicy Bypass -File install.ps1 uninstall     # 卸载
#   powershell -ExecutionPolicy Bypass -File install.ps1 --help
#
# 一键安装（PowerShell 7+）：
#   irm https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

# ---------- 常量 ----------
$REPO_URL    = "https://github.com/wepigcn/open-wepig-skills.git"
$REPO_OWNER  = "wepigcn"
$REPO_NAME   = "open-wepig-skills"
$MARKETPLACE_NAME = "open-wepig-skills"
$SKILL_NAME  = "open-wepig"
$CMD_NAME    = "open-wepig-cli"
$INSTALL_DIR = if ($env:OPEN_WEPIG_INSTALL_DIR) { $env:OPEN_WEPIG_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "open-wepig-skills" }
$ENV_DIR     = Join-Path $env:USERPROFILE ".config\open-wepig"
$ENV_FILE    = Join-Path $ENV_DIR "env.ps1"
$SKILL_SRC   = Join-Path $INSTALL_DIR "skills\$SKILL_NAME"
$WES_ABS     = Join-Path $INSTALL_DIR "scripts\open-cli.mjs"
$BINDIR      = Join-Path $env:USERPROFILE ".local\bin"

# 项目级安装参数（由参数解析填充）
$PROJECT_DIR = $null
$PROJECT_ENV_FILE = $null

# ---------- 输出辅助 ----------
function Write-Cyan($msg)  { Write-Host $msg -ForegroundColor Cyan }
function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Yellow($msg){ Write-Host $msg -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host $msg -ForegroundColor Red -ErrorAction Continue }

function Usage {
  Write-Host "用法: powershell -File install.ps1 [install|update|uninstall|--help] [--project [DIR]]"
  Write-Host "  install    交互式安装（默认）：鉴权 + 生成 open-wepig-cli 命令 + 装 harness + 实测"
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
}

# ---------- 鉴权 ----------
function Ask-Auth {
  Write-Host "需要 open-wepig 网关鉴权，两项均为必填。"
  $script:AppId = Read-Host "OPEN_WEPIG_APPID"
  while ([string]::IsNullOrWhiteSpace($script:AppId)) {
    Write-Err "APPID 不能为空"; $script:AppId = Read-Host "OPEN_WEPIG_APPID"
  }
  $secure = Read-Host "OPEN_WEPIG_SECRET（输入不回显）" -AsSecureString
  $script:Secret = [System.Net.NetworkCredential]::new("", $secure).Password
  while ([string]::IsNullOrWhiteSpace($script:Secret)) {
    Write-Err "SECRET 不能为空"
    $secure = Read-Host "OPEN_WEPIG_SECRET" -AsSecureString
    $script:Secret = [System.Net.NetworkCredential]::new("", $secure).Password
  }
}

function Ensure-Profile {
  $dir = Split-Path $PROFILE -Parent
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
}

function Update-ProfileLine($marker, $line) {
  Ensure-Profile
  $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
  if ($content -and ($content -match [regex]::Escape($marker))) { return }
  Add-Content -Path $PROFILE -Value "`n$line"
}

function Write-Env {
  New-Item -ItemType Directory -Path $ENV_DIR -Force | Out-Null
  $envContent = @"
# open-wepig 鉴权，由 install.ps1 生成
`$env:OPEN_WEPIG_APPID = "$script:AppId"
`$env:OPEN_WEPIG_SECRET = "$script:Secret"
"@
  $envContent | Set-Content -Path $ENV_FILE -Encoding UTF8
  Write-Green "已写入 $ENV_FILE"
  $srcLine = '. "$env:USERPROFILE\.config\open-wepig\env.ps1"  # open-wepig-skills'
  Update-ProfileLine "open-wepig\env" $srcLine
  # 清理旧的 .env 文件（从早期版本迁移）
  $oldEnv = Join-Path $env:USERPROFILE ".open-wepig.env"
  if (Test-Path $oldEnv) { Remove-Item $oldEnv -Force; Write-Yellow "已清理旧文件 $oldEnv" }
}

function Migrate-Env {
  $oldEnv = Join-Path $env:USERPROFILE ".open-wepig.env"
  if (Test-Path $oldEnv) {
    New-Item -ItemType Directory -Path $ENV_DIR -Force | Out-Null
    if (!(Test-Path $ENV_FILE)) { Copy-Item $oldEnv $ENV_FILE -Force }
    Remove-Item $oldEnv -Force
    Write-Green "已迁移鉴权文件 $oldEnv -> $ENV_FILE"
  }
  $srcLine = '. "$env:USERPROFILE\.config\open-wepig\env.ps1"  # open-wepig-skills'
  Update-ProfileLine "open-wepig\env" $srcLine
}

function Write-ProjectEnv {
  $envContent = @"
# open-wepig 鉴权，由 install.ps1 生成（项目级）
`$env:OPEN_WEPIG_APPID = "$script:AppId"
`$env:OPEN_WEPIG_SECRET = "$script:Secret"
"@
  $envContent | Set-Content -Path $PROJECT_ENV_FILE -Encoding UTF8
  Write-Green "已写入 $PROJECT_ENV_FILE"
}

# ---------- 生成 open-wepig-cli 命令 ----------
function Write-CLIWrapper {
  New-Item -ItemType Directory -Path $BINDIR -Force | Out-Null
  $wrapper = "@echo off`r`nnode `"$WES_ABS`" %*"
  $cmdPath = Join-Path $BINDIR "$CMD_NAME.cmd"
  Set-Content -Path $cmdPath -Value $wrapper -Encoding ASCII
  $pathLine = '$env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"  # open-wepig-skills'
  Update-ProfileLine ".local\bin" $pathLine
}

# ---------- 仓库同步 ----------
function Sync-Repo {
  if (Test-Path (Join-Path $INSTALL_DIR ".git")) {
    Write-Host "已存在仓库，拉取更新..."
    git -C $INSTALL_DIR pull --ff-only
  } else {
    Write-Host "克隆仓库..."
    git clone $REPO_URL $INSTALL_DIR
  }
}

# ---------- 各平台安装 ----------
function Link-Skill($targetDir) {
  $target = Join-Path $targetDir $SKILL_NAME
  $parent = Split-Path $target -Parent
  if (!(Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  if (Test-Path $target) { cmd /c rmdir "$target" 2>$null; Remove-Item $target -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Junction -Path $target -Target $SKILL_SRC | Out-Null
  Write-Green "已链接 $target"
}

# 项目模式下，非文件系统 harness 本质全局生效，给出提示
function Global-HarnessWarning($name) {
  if ($PROJECT_DIR) {
    Write-Yellow "注意：$name 为全局插件/扩展，不局限于此项目"
  }
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
  copilot plugin marketplace add "$REPO_OWNER/$REPO_NAME" 2>$null
  if (copilot plugin install "$SKILL_NAME@$MARKETPLACE_NAME") { Write-Green "Copilot CLI 插件已安装" }
  else { Write-Err "Copilot 安装失败，请手动排查" }
}

function Install-Antigravity {
  Global-HarnessWarning "Antigravity"
  if (!(Get-Command agy -ErrorAction SilentlyContinue)) {
    Write-Yellow "未检测到 agy。装好后执行：agy plugin install $REPO_URL"; return
  }
  if (agy plugin install $REPO_URL) { Write-Green "Antigravity 插件已安装" }
  else { Write-Err "Antigravity 安装失败" }
}

function Install-Gemini {
  Global-HarnessWarning "Gemini CLI"
  if (!(Get-Command gemini -ErrorAction SilentlyContinue)) {
    Write-Yellow "未检测到 gemini。装好后执行：gemini extensions install $REPO_URL"; return
  }
  if (gemini extensions install $REPO_URL) { Write-Green "Gemini 扩展已安装" }
  else { Write-Err "Gemini 安装失败，请手动执行：gemini extensions install $REPO_URL" }
}

function Install-Codex {
  Global-HarnessWarning "Codex CLI"
  if (!(Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Yellow "未检测到 codex。装好后执行：codex marketplace add $REPO_OWNER/$REPO_NAME，再在 /plugins 安装 open-wepig"; return
  }
  codex marketplace add "$REPO_OWNER/$REPO_NAME" 2>$null
  Write-Green "Codex marketplace 已注册。请在 Codex CLI 的 /plugins 中安装 open-wepig"
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
    if (!$json.plugin) { $json | Add-Member -NotePropertyName plugin -NotePropertyValue @() }
    if ($json.plugin -notcontains $plugin) {
      $json.plugin += $plugin
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
  copilot plugin marketplace add "$REPO_OWNER/$REPO_NAME" 2>$null
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
  codex marketplace add "$REPO_OWNER/$REPO_NAME" 2>$null
  Write-Green "Codex：marketplace 已刷新（plugin 内容随 repo pull 更新）"
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
  if (Test-Path $p) {
    cmd /c rmdir "$p" 2>$null
    Remove-Item $p -Force -ErrorAction SilentlyContinue
    $prefix = if ($PROJECT_DIR) { "项目级 " } else { "" }
    Write-Green "Claude Code：已删${prefix}链接"
  }
}
function Uninstall-Cursor {
  $base = if ($PROJECT_DIR) { $PROJECT_DIR } else { $env:USERPROFILE }
  $p = Join-Path $base ".cursor\skills\$SKILL_NAME"
  if (Test-Path $p) {
    cmd /c rmdir "$p" 2>$null
    Remove-Item $p -Force -ErrorAction SilentlyContinue
    $prefix = if ($PROJECT_DIR) { "项目级 " } else { "" }
    Write-Green "Cursor：已删${prefix}链接"
  }
}

function Uninstall-Copilot {
  if (!(Get-Command copilot -ErrorAction SilentlyContinue)) { return }
  copilot plugin uninstall "$SKILL_NAME@$MARKETPLACE_NAME" 2>$null
  Write-Green "Copilot CLI：已尝试卸载"
}
function Uninstall-Antigravity {
  if (!(Get-Command agy -ErrorAction SilentlyContinue)) { return }
  agy plugin uninstall $SKILL_NAME 2>$null; if (!$?) { agy plugin remove $SKILL_NAME 2>$null }
  Write-Green "Antigravity：已尝试卸载"
}
function Uninstall-Gemini {
  if (!(Get-Command gemini -ErrorAction SilentlyContinue)) { return }
  gemini extensions remove $SKILL_NAME 2>$null; if (!$?) { gemini extensions uninstall $SKILL_NAME 2>$null }
  Write-Green "Gemini：已尝试卸载"
}
function Uninstall-Codex {
  if (!(Get-Command codex -ErrorAction SilentlyContinue)) { return }
  codex marketplace remove "$REPO_OWNER/$REPO_NAME" 2>$null; if (!$?) { codex plugin uninstall $SKILL_NAME 2>$null }
  Write-Green "Codex：已尝试卸载"
}
function Uninstall-OpenCode {
  $cfg = Join-Path $env:USERPROFILE ".config\opencode\opencode.json"
  if (!(Test-Path $cfg)) { return }
  try {
    $json = Get-Content $cfg -Raw | ConvertFrom-Json
    $plugin = "file://$INSTALL_DIR"
    if ($json.plugin) {
      $json.plugin = @($json.plugin | Where-Object { $_ -ne $plugin })
      $json | ConvertTo-Json -Depth 10 | Set-Content $cfg -Encoding UTF8
      Write-Green "OpenCode：已从 plugin 数组移除"
    }
  } catch {
    Write-Yellow "OpenCode：$cfg 解析失败，请手动移除"
  }
}

function Clean-Profile {
  if (!(Test-Path $PROFILE)) { return }
  $content = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
  if (!$content -or !(Select-String -InputObject $content -Pattern "open-wepig-skills" -Quiet)) { return }
  Copy-Item $PROFILE "$PROFILE.bak.open-wepig"
  $lines = $content -split "`r?`n" | Where-Object { $_ -notmatch "open-wepig-skills" }
  $lines -join "`n" | Set-Content -Path $PROFILE -NoNewline
  Write-Green "已清理 $PROFILE（备份 $PROFILE.bak.open-wepig）"
}

# ---------- 实测 ----------
function Verify {
  Write-Cyan "验证鉴权与连通性..."
  if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Yellow "未检测到 node，跳过实测。装好后执行：$CMD_NAME services"
    return
  }
  $envToSource = if ($PROJECT_DIR) { $PROJECT_ENV_FILE } else { $ENV_FILE }
  try {
    . $envToSource
    $output = node $WES_ABS services 2>&1
    if ($LASTEXITCODE -eq 0) {
      Write-Green "鉴权与连通性正常"
    } else {
      Write-Err "实测失败（appid/secret 错误、网络不通或网关未授权）："
      Write-Host $output
      Write-Yellow "修正：编辑 $envToSource 后重跑，或重新安装"
    }
  } catch {
    Write-Err "实测失败：$_"
    Write-Yellow "修正：编辑 $envToSource 后重跑，或重新安装"
  }
}

# ---------- 安装流程 ----------
function Do-Install {
  Write-Cyan "open-wepig-skills 安装程序"
  if ($PROJECT_DIR) {
    if (Test-Path $PROJECT_ENV_FILE) {
      $reuse = Read-Host "检测到项目级鉴权文件，是否复用？[Y/n]"
      if ($reuse -notmatch "^[Nn]$") {
        Write-Green "复用已有项目级鉴权文件"
        . $PROJECT_ENV_FILE
      } else {
        Ask-Auth
        Write-ProjectEnv
      }
    } else {
      Ask-Auth
      Write-ProjectEnv
    }
  } else {
    if (Test-Path $ENV_FILE) {
      $reuse = Read-Host "检测到已有鉴权文件，是否复用？[Y/n]"
      if ($reuse -notmatch "^[Nn]$") {
        Write-Green "复用已有鉴权文件"
        Migrate-Env
      } else {
        Ask-Auth
        Write-Env
      }
    } else {
      Ask-Auth
      Write-Env
    }
  }
  Sync-Repo
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
  Verify
  Write-Host ""
  Write-Green "安装完成。"
  if ($PROJECT_DIR) {
    Write-Host "当前终端执行以下命令立即生效：. $PROJECT_ENV_FILE"
    Write-Host "（项目级鉴权优先于全局 `$env:USERPROFILE\.config\open-wepig\env.ps1）"
  } else {
    Write-Host "当前终端执行以下命令立即生效：. $ENV_FILE"
    Write-Host "或新开终端后即可用 $CMD_NAME 命令（如 $CMD_NAME services）。"
  }
}

# ---------- 更新流程 ----------
function Do-Update {
  Write-Cyan "open-wepig-skills 更新"
  Sync-Repo
  if ($PROJECT_DIR) {
    if (Test-Path $PROJECT_ENV_FILE) {
      $reuse = Read-Host "检测到项目级鉴权文件，是否复用？[Y/n]"
      if ($reuse -notmatch "^[Nn]$") {
        Write-Green "复用已有项目级鉴权文件"
        . $PROJECT_ENV_FILE
      } else {
        Ask-Auth
        Write-ProjectEnv
      }
    } else {
      Ask-Auth
      Write-ProjectEnv
    }
  } else {
    Migrate-Env
  }
  Write-CLIWrapper
  Write-Host ""
  Update-Claude; Update-Cursor; Update-Copilot; Update-Antigravity
  Update-Gemini; Update-Codex; Update-OpenCode
  Verify
  Write-Host ""
  Write-Green "更新完成。"
  if ($PROJECT_DIR) {
    Write-Host "当前终端执行：. $PROJECT_ENV_FILE  刷新环境"
  } else {
    Write-Host "如鉴权文件已迁移，当前终端执行：. $ENV_FILE  刷新环境"
  }
}

# ---------- 卸载流程 ----------
function Do-Uninstall {
  Write-Cyan "open-wepig-skills 卸载"
  if ($PROJECT_DIR) {
    Write-Host "将删除项目级内容："
    Write-Host "  - $(Join-Path $PROJECT_DIR ".claude\skills\$SKILL_NAME")"
    Write-Host "  - $(Join-Path $PROJECT_DIR ".cursor\skills\$SKILL_NAME")"
    Write-Host "  - $PROJECT_ENV_FILE"
    Write-Yellow "注意：Copilot / Antigravity / Gemini / Codex / OpenCode 为全局插件，将执行全局卸载"
  } else {
    Write-Host "将删除："
    Write-Host "  - 命令 $(Join-Path $BINDIR "$CMD_NAME.cmd")"
    Write-Host "  - 各 harness 的链接 / plugin 注册"
    Write-Host "  - 鉴权文件 $ENV_FILE"
    Write-Host "  - PowerShell profile 里的 open-wepig-skills 行（保留 .bak 备份）"
  }
  $confirm = Read-Host "确认卸载？[y/N]"
  if ($confirm -notmatch "^[Yy]$") { Write-Yellow "已取消"; return }

  if ($PROJECT_DIR) {
    Uninstall-Claude; Uninstall-Cursor
    if (Test-Path $PROJECT_ENV_FILE) { Remove-Item $PROJECT_ENV_FILE -Force; Write-Green "已删 $PROJECT_ENV_FILE" }
    Uninstall-Copilot; Uninstall-Antigravity; Uninstall-Gemini; Uninstall-Codex; Uninstall-OpenCode
  } else {
    $cmdPath = Join-Path $BINDIR "$CMD_NAME.cmd"
    if (Test-Path $cmdPath) { Remove-Item $cmdPath -Force; Write-Green "已删命令 $cmdPath" }
    Uninstall-Claude; Uninstall-Cursor; Uninstall-Copilot; Uninstall-Antigravity
    Uninstall-Gemini; Uninstall-Codex; Uninstall-OpenCode
    if (Test-Path $ENV_FILE) { Remove-Item $ENV_FILE -Force; Write-Green "已删 $ENV_FILE" }
    Clean-Profile

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
  $script:PROJECT_ENV_FILE = Join-Path $script:PROJECT_DIR ".open-wepig.env.ps1"
}

switch ($script:ACTION) {
  "install"   { Do-Install }
  "update"    { Do-Update }
  "uninstall" { Do-Uninstall }
  "-h"        { Usage }
  "--help"    { Usage }
  default     { Write-Err "未知参数: $script:ACTION"; Usage }
}
