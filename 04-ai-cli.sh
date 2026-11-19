#!/usr/bin/env bash
#
# ai-tools.sh —— Mac 重装系统后，一键安装 / 卸载常用 AI 命令行工具
#
#   1) Claude Code   curl -fsSL https://claude.ai/install.sh | bash
#   2) Codex         curl -fsSL https://chatgpt.com/codex/install.sh | sh
#   3) Pi            curl -fsSL https://pi.dev/install.sh | sh
#
# 用法：
#   bash ai-tools.sh
#
# 说明：只走官网安装脚本，卸载也只按官网安装的位置清理——
#       删掉可执行文件 + 该工具的配置 / 登录 / 会话 / 缓存，
#       避免旧配置残留导致下次装回来行为不一致。

set -uo pipefail

# 让脚本自己也能找到刚装好的命令（这些安装脚本都装到 ~/.local/bin）
export PATH="$HOME/.local/bin:$PATH"

TOOLS=("Claude Code" "Codex" "Pi")

ACTION=""    # install / uninstall / quit
SELECTED=()  # 选中的编号，例如 (1 3)

# ------------------------------------------------------------------
# 输出
# ------------------------------------------------------------------

say()  { printf '%s\n' "$*"; }
ok()   { printf '   ✓ %s\n' "$*"; }
warn() { printf '   ! %s\n' "$*"; }

# 询问 y/N，默认 N
confirm() {
  local answer=""
  printf '%s [y/N] ' "$1"
  read -r answer || answer=""
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# ------------------------------------------------------------------
# 卸载用的公共函数
# ------------------------------------------------------------------

# 删除文件或目录（存在才删，不存在就安静跳过）
remove_path() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path" && ok "已删除 $path"
  fi
}

# 卸载后如果命令还在，提示残留位置，避免留下看不见的东西
check_leftover() {
  local cmd="$1" found=""
  hash -r 2>/dev/null
  found=$(command -v "$cmd" 2>/dev/null || true)
  if [ -n "$found" ]; then
    warn "仍能找到 ${found} ，如需彻底清除请手动删除"
  fi
}

# 把 ~/.local/bin 写进 ~/.zshrc（已存在就不重复写）
ensure_path() {
  local line='export PATH="$HOME/.local/bin:$PATH"'
  touch "$HOME/.zshrc"
  if grep -qF "$line" "$HOME/.zshrc"; then
    ok "~/.zshrc 里已有 PATH 配置"
  else
    printf '\n%s\n' "$line" >> "$HOME/.zshrc"
    ok "已把 ~/.local/bin 加入 ~/.zshrc"
  fi
}

# ------------------------------------------------------------------
# 安装
# ------------------------------------------------------------------

# 跑官网安装脚本：下载到临时文件再执行。
# 这些安装脚本收尾会弹交互提问（Codex 的 "Start Codex now?"、Pi 的 "Choose an action"），
# 而且它们直接读写 /dev/tty，用管道喂答案是喂不进去的。所以放进一个没有控制终端的
# 子进程里跑（perl 的 setsid），它们就会自动走非交互分支，一路装完。
run_installer() {
  local url="$1" shell="${2:-bash}" file="" log="" code=0
  file=$(mktemp) || return 1
  log=$(mktemp) || return 1
  if ! curl -fsSL "$url" -o "$file"; then
    rm -f "$file" "$log"
    return 1
  fi
  perl -e 'use POSIX (); POSIX::setsid(); exec @ARGV' \
    "$shell" "$file" </dev/null >"$log" 2>&1
  code=$?
  cat "$log"
  rm -f "$file" "$log"
  return "$code"
}

install_claude() {
  say "→ 安装 Claude Code ..."
  if run_installer https://claude.ai/install.sh bash; then
    ensure_path
    ok "Claude Code 安装完成"
  else
    warn "Claude Code 安装失败"
  fi
}

install_codex() {
  say "→ 安装 Codex ..."
  if run_installer https://chatgpt.com/codex/install.sh sh; then
    ensure_path
    ok "Codex 安装完成"
  else
    warn "Codex 安装失败"
  fi
}

install_pi() {
  say "→ 安装 Pi ..."
  if run_installer https://pi.dev/install.sh sh; then
    ensure_path
    ok "Pi 安装完成"
  else
    warn "Pi 安装失败"
  fi
}

# ------------------------------------------------------------------
# 卸载（含配置、会话、缓存）
# ------------------------------------------------------------------

uninstall_claude() {
  say "→ 卸载 Claude Code ..."
  remove_path "$HOME/.local/bin/claude"        # 可执行文件
  remove_path "$HOME/.local/share/claude"      # 版本目录
  remove_path "$HOME/.claude"                  # 配置 / 登录 / 会话 / 缓存
  remove_path "$HOME/.claude.json"             # 全局配置
  remove_path "$HOME/.claude.json.backup"
  check_leftover claude
}

uninstall_codex() {
  say "→ 卸载 Codex ..."
  remove_path "$HOME/.local/bin/codex"         # 可执行文件
  remove_path "$HOME/.codex"                   # 配置 / 登录 / 会话 / 缓存
  check_leftover codex
}

uninstall_pi() {
  say "→ 卸载 Pi ..."
  remove_path "$HOME/.local/bin/pi"            # 可执行文件
  remove_path "$HOME/.pi"                      # 配置 / 登录 / 会话 / 缓存
  remove_path "$HOME/.config/pi"               # 部分版本放这里
  check_leftover pi
}

# ------------------------------------------------------------------
# 交互
# ------------------------------------------------------------------

choose_action() {
  local choice=""
  while [ -z "$ACTION" ]; do
    say ""
    say "======================================"
    say "   AI 命令行工具  安装 / 卸载"
    say "======================================"
    say "   1) 安装"
    say "   2) 卸载（含配置与缓存）"
    say "   3) 退出"
    say "======================================"
    printf '请选择 [1-3]: '
    read -r choice || choice=""
    case "$choice" in
      1) ACTION="install" ;;
      2) ACTION="uninstall" ;;
      3) ACTION="quit" ;;
      *) warn "请输入 1、2 或 3" ;;
    esac
  done
}

choose_tools() {
  SELECTED=()
  local i=1 t="" line="" token=""

  say ""
  say "要处理哪些工具？（可多选，用空格或逗号分隔，例如：1 3）"
  for t in "${TOOLS[@]}"; do
    say "   $i) $t"
    i=$((i + 1))
  done
  printf '> '
  read -r line || line=""

  for token in ${line//,/ }; do
    case "$token" in
      1|2|3) SELECTED+=("$token") ;;
      *) warn "忽略无效输入：$token" ;;
    esac
  done

  if [ ${#SELECTED[@]} -eq 0 ]; then
    warn "没有选中任何工具"
    return 1
  fi

  # 去重，避免同一个工具跑两遍
  SELECTED=($(printf '%s\n' "${SELECTED[@]}" | sort -u))
  return 0
}

run_selected() {
  local index=""
  for index in "${SELECTED[@]}"; do
    case "$ACTION:$index" in
      install:1)   install_claude ;;
      install:2)   install_codex ;;
      install:3)   install_pi ;;
      uninstall:1) uninstall_claude ;;
      uninstall:2) uninstall_codex ;;
      uninstall:3) uninstall_pi ;;
    esac
  done
}

# ------------------------------------------------------------------
# 主流程
# ------------------------------------------------------------------

main() {
  choose_action

  if [ "$ACTION" = "quit" ]; then
    say "已退出。"
    exit 0
  fi

  choose_tools || exit 0

  # 卸载是破坏性操作，先确认
  if [ "$ACTION" = "uninstall" ]; then
    local index=""
    say ""
    say "即将卸载并清除以下工具的配置与缓存："
    for index in "${SELECTED[@]}"; do
      say "   - ${TOOLS[$((index - 1))]}"
    done
    if ! confirm "确认继续？"; then
      say "已取消。"
      exit 0
    fi
  fi

  say ""
  run_selected

  say ""
  say "全部完成。"
  if [ "$ACTION" = "install" ]; then
    say "新开一个终端窗口（或执行 source ~/.zshrc）后即可使用。"
  fi
}

main
