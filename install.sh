#!/usr/bin/env bash
# open-wepig-skills 安装、更新与卸载脚本
# 用法：
#   bash install.sh              # 安装（交互鉴权 + 生成 open-wepig-cli 命令 + 选 harness + 实测）
#   bash install.sh update        # 更新（拉取最新 + 各平台同步 + 刷新 open-wepig-cli 命令）
#   bash install.sh uninstall     # 卸载（删命令、symlink、鉴权、shell 配置行；clone 目录可选）
#   bash install.sh --help

set -euo pipefail

REPO_URL="https://github.com/wepigcn/open-wepig-skills.git"
REPO_OWNER="wepigcn"
REPO_NAME="open-wepig-skills"
MARKETPLACE_NAME="open-wepig-skills"
SKILL_NAME="open-wepig"          # skill / plugin / 扩展名
CMD_NAME="open-wepig-cli"        # 生成的 PATH 命令名
INSTALL_DIR="${OPEN_WEPIG_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/open-wepig-skills}"
ENV_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/open-wepig"
ENV_FILE="$ENV_DIR/env"
SKILL_SRC="$INSTALL_DIR/skills/$SKILL_NAME"
WES_ABS="$INSTALL_DIR/scripts/open-cli.mjs"
BINDIR="$HOME/.local/bin"

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
用法: bash install.sh [install|update|uninstall|--help]
  install    交互式安装（默认）：鉴权 + 生成 open-wepig-cli 命令 + 装 harness + 实测
  update     拉取最新并同步到各已安装 harness
  uninstall  卸载：删命令、symlink、鉴权、shell 配置行（clone 目录可选）
EOF
}

# ---------- 鉴权 ----------
ask_auth() {
  echo "需要 open-wepig 网关鉴权，两项均为必填。"
  read_tty -rp "OPEN_WEPIG_APPID: " APPID
  while [[ -z "${APPID//[[:space:]]/}" ]]; do
    err "APPID 不能为空"; read_tty -rp "OPEN_WEPIG_APPID: " APPID
  done
  read_tty -rsp "OPEN_WEPIG_SECRET（输入不回显）: " SECRET; echo
  while [[ -z "${SECRET//[[:space:]]/}" ]]; do
    err "SECRET 不能为空"; read_tty -rsp "OPEN_WEPIG_SECRET: " SECRET; echo
  done
}

ensure_env_path() {
  if ! grep -qF '# open-wepig-skills PATH' "$ENV_FILE" 2>/dev/null; then
    cat >> "$ENV_FILE" <<'EOF'

# open-wepig-skills PATH
OPEN_WEPIG_BINDIR="$HOME/.local/bin"
case ":$PATH:" in
  *":$OPEN_WEPIG_BINDIR:"*) ;;
  *) export PATH="$OPEN_WEPIG_BINDIR:$PATH" ;;
esac
unset OPEN_WEPIG_BINDIR
EOF
  fi
}

write_env() {
  mkdir -p "$ENV_DIR"; chmod 700 "$ENV_DIR"
  touch "$ENV_FILE"; chmod 600 "$ENV_FILE"
  cat > "$ENV_FILE" <<EOF
# open-wepig 鉴权，由 install.sh 生成
export OPEN_WEPIG_APPID="$APPID"
export OPEN_WEPIG_SECRET="$SECRET"
EOF
  ensure_env_path
  green "已写入 ${ENV_FILE}（权限 600）"
  local src_line='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/open-wepig/env" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/open-wepig/env"  # open-wepig-skills'
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    touch "$rc"
    if grep -qF '.open-wepig.env' "$rc" 2>/dev/null; then
      grep -vF '.open-wepig.env' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc" || rm -f "$rc.tmp"
    fi
    grep -qF 'open-wepig/env' "$rc" 2>/dev/null || printf '\n%s\n' "$src_line" >> "$rc"
  done
  if [[ -f "$HOME/.open-wepig.env" ]]; then
    rm -f "$HOME/.open-wepig.env"
    yellow "已清理旧文件 ~/.open-wepig.env"
  fi
}

migrate_env() {
  local old="$HOME/.open-wepig.env"
  local src_line='[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/open-wepig/env" ] && source "${XDG_CONFIG_HOME:-$HOME/.config}/open-wepig/env"  # open-wepig-skills'
  if [[ -f "$old" ]]; then
    mkdir -p "$ENV_DIR"; chmod 700 "$ENV_DIR"
    [[ -f "$ENV_FILE" ]] || { cp "$old" "$ENV_FILE"; chmod 600 "$ENV_FILE"; }
    rm -f "$old"
    green "已迁移鉴权文件 $old → ${ENV_FILE}"
  fi
  ensure_env_path
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    touch "$rc"
    if grep -qF '.open-wepig.env' "$rc" 2>/dev/null; then
      grep -vF '.open-wepig.env' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc" || rm -f "$rc.tmp"
    fi
    grep -qF 'open-wepig/env' "$rc" 2>/dev/null || printf '\n%s\n' "$src_line" >> "$rc"
  done
}

# ---------- 生成 open-wepig-cli PATH 命令 ----------
write_wepig_wrapper() {
  mkdir -p "$BINDIR"
  cat > "$BINDIR/$CMD_NAME" <<EOF
#!/usr/bin/env bash
# 由 open-wepig-skills install.sh 生成
exec node "$WES_ABS" "\$@"
EOF
  chmod +x "$BINDIR/$CMD_NAME"
}

# ---------- 仓库同步 ----------
sync_repo() {
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    echo "已存在仓库，拉取更新..."; git -C "$INSTALL_DIR" pull --ff-only
  else
    echo "克隆仓库..."; git clone "$REPO_URL" "$INSTALL_DIR"
  fi
}

# ---------- 各平台安装 ----------
link_skill() { mkdir -p "$1"; ln -sfn "$SKILL_SRC" "$1/$SKILL_NAME"; green "已链接 $1/$SKILL_NAME"; }
install_claude() { link_skill "$HOME/.claude/skills"; }
install_cursor() { link_skill "$HOME/.cursor/skills"; }

install_copilot() {
  if ! command -v copilot >/dev/null 2>&1; then
    yellow "未检测到 copilot。装好后执行：copilot plugin marketplace add $REPO_OWNER/$REPO_NAME && copilot plugin install $SKILL_NAME@$MARKETPLACE_NAME"; return
  fi
  copilot plugin marketplace add "$REPO_OWNER/$REPO_NAME" || true
  if copilot plugin install "$SKILL_NAME@$MARKETPLACE_NAME"; then green "Copilot CLI 插件已安装"
  else err "Copilot 安装失败，请手动排查"; fi
}

install_antigravity() {
  if ! command -v agy >/dev/null 2>&1; then
    yellow "未检测到 agy。装好后执行：agy plugin install $REPO_URL"; return
  fi
  if agy plugin install "$REPO_URL"; then green "Antigravity 插件已安装"
  else err "Antigravity 安装失败"; fi
}

install_gemini() {
  if ! command -v gemini >/dev/null 2>&1; then
    yellow "未检测到 gemini。装好后执行：gemini extensions install $REPO_URL"; return
  fi
  if gemini extensions install "$REPO_URL"; then green "Gemini 扩展已安装"
  else err "Gemini 安装失败，请手动执行：gemini extensions install $REPO_URL"; fi
}

install_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    yellow "未检测到 codex。装好后执行：codex marketplace add $REPO_OWNER/${REPO_NAME}，再在 /plugins 安装 open-wepig"; return
  fi
  codex marketplace add "$REPO_OWNER/$REPO_NAME" || true
  green "Codex marketplace 已注册。请在 Codex CLI 的 /plugins 中安装 open-wepig"
}

install_opencode() {
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
update_claude() { [[ -e "$HOME/.claude/skills/$SKILL_NAME" ]] && green "Claude Code：symlink 随 repo pull 自动更新" || true; }
update_cursor() { [[ -e "$HOME/.cursor/skills/$SKILL_NAME" ]] && green "Cursor：symlink 随 repo pull 自动更新" || true; }

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
  codex marketplace add "$REPO_OWNER/$REPO_NAME" >/dev/null 2>&1 || true
  green "Codex：marketplace 已刷新（plugin 内容随 repo pull 更新）"
}

update_opencode() {
  grep -qF "file://$INSTALL_DIR" "$HOME/.config/opencode/opencode.json" 2>/dev/null && green "OpenCode：file:// 引用随 repo pull 自动更新" || true
}

# ---------- 各平台卸载 ----------
uninstall_claude() { rm -f "$HOME/.claude/skills/$SKILL_NAME" 2>/dev/null && green "Claude Code：已删 symlink" || true; }
uninstall_cursor() { rm -f "$HOME/.cursor/skills/$SKILL_NAME" 2>/dev/null && green "Cursor：已删 symlink" || true; }

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
  { codex marketplace remove "$REPO_OWNER/$REPO_NAME" || codex plugin uninstall "$SKILL_NAME"; } >/dev/null 2>&1 || true
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
    grep -qF '# open-wepig-skills' "$rc" || continue
    cp "$rc" "$rc.bak.open-wepig"
    if grep -vF '# open-wepig-skills' "$rc" > "$rc.tmp" && mv "$rc.tmp" "$rc"; then
      green "已清理 ${rc}（备份 $rc.bak.open-wepig）"
    else
      rm -f "$rc.tmp"; yellow "$rc 清理失败，保留原文件"
    fi
  done
}

# ---------- 实测 ----------
verify() {
  cyan "验证鉴权与连通性..."
  local log; log="$(mktemp -t open-wepig-test)"
  if ! command -v node >/dev/null 2>&1; then
    yellow "未检测到 node，跳过实测。装好后执行：$CMD_NAME services"
  elif ( source "$ENV_FILE" && node "$WES_ABS" services ) >"$log" 2>&1; then
    green "鉴权与连通性正常"
  else
    err "实测失败（appid/secret 错误、网络不通或网关未授权）："
    cat "$log" 2>/dev/null || true
    yellow "修正：编辑 $ENV_FILE 后重跑，或重新安装"
  fi
  rm -f "$log" 2>/dev/null || true
}

# ---------- 安装流程 ----------
do_install() {
  cyan "open-wepig-skills 安装程序"
  if [[ -f "$ENV_FILE" ]]; then
    read_tty -rp "检测到已有鉴权文件，是否复用？[Y/n] " reuse
    if [[ ! "$reuse" =~ ^[Nn]$ ]]; then
      green "复用已有鉴权文件"
      migrate_env
    else
      ask_auth
      write_env
    fi
  else
    ask_auth
    write_env
  fi
  sync_repo
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
  verify
  echo; green "安装完成。"
  echo "当前终端执行以下命令立即生效：source ${ENV_FILE}"
}

# ---------- 更新流程 ----------
do_update() {
  cyan "open-wepig-skills 更新"
  sync_repo
  migrate_env
  write_wepig_wrapper
  echo
  update_claude; update_cursor; update_copilot; update_antigravity
  update_gemini; update_codex; update_opencode
  verify
  echo; green "更新完成。"
  echo "如鉴权文件已迁移，当前终端执行：source ${ENV_FILE}  刷新环境"
}

# ---------- 卸载流程 ----------
do_uninstall() {
  cyan "open-wepig-skills 卸载"
  echo "将删除："
  echo "  - 命令 $BINDIR/$CMD_NAME"
  echo "  - 各 harness 的 symlink / plugin 注册"
  echo "  - 鉴权文件 $ENV_FILE"
  echo "  - shell 配置里的 open-wepig-skills 行（~/.zshrc、~/.bashrc，保留 .bak 备份）"
  read_tty -rp "确认卸载？[y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then yellow "已取消"; return; fi

  rm -f "$BINDIR/$CMD_NAME" 2>/dev/null && green "已删命令 $BINDIR/$CMD_NAME" || true
  uninstall_claude; uninstall_cursor; uninstall_copilot; uninstall_antigravity
  uninstall_gemini; uninstall_codex; uninstall_opencode
  rm -f "$ENV_FILE" "$HOME/.open-wepig.env" 2>/dev/null && green "已删 $ENV_FILE" || true
  clean_rc

  echo
  read_tty -rp "是否删除 clone 目录 ${INSTALL_DIR}？[y/N] " delrepo
  if [[ "$delrepo" =~ ^[Yy]$ ]]; then
    rm -rf "$INSTALL_DIR" && green "已删 $INSTALL_DIR"
  else
    yellow "保留 clone 目录 ${INSTALL_DIR}（可手动 rm -rf 删除）"
  fi
  echo; green "卸载完成。"
}

case "${1:-install}" in
  install|"") do_install ;;
  update) do_update ;;
  uninstall) do_uninstall ;;
  -h|--help) usage ;;
  *) err "未知参数: $1"; usage; exit 1 ;;
esac
