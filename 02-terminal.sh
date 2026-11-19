#!/usr/bin/env bash
# ============================================================
# 02-terminal.sh —— 终端环境
#
# 前提：Homebrew 已经装好；没装会直接报错退出（先跑完 01，或在 brew.sh 装好）
# 内容：Ghostty 终端 + Oh My Zsh + Starship 提示符 + 两个 zsh 插件
#
# 这个脚本只碰两个文件，别的都不动：
#   1) ~/.ghostty-zsh-starship.zsh  完整配置都写在这里，脚本全权管理
#   2) ~/.zshrc                     只追加一个带标记的 source 块
#      重复执行时会先删掉旧块再写，不会一层层叠加
#
# 用法：
#   ./02-terminal.sh          安装
#   ./02-terminal.sh -h       看说明
#
# 幂等：已装的 cask / formula / 插件都会跳过，可以反复执行。
# ============================================================

set -euo pipefail

# ---------- 配置区：路径和清单集中在这里 ----------

SCRIPT_NAME="$(basename "$0")"

# .zshrc 里用这对标记圈出一段「受管块」，反复执行时靠它精确替换
MANAGED_CONFIG_FILE="$HOME/.ghostty-zsh-starship.zsh"
MANAGED_BLOCK_START="# >>> ghostty-zsh-starship >>>"
MANAGED_BLOCK_END="# <<< ghostty-zsh-starship <<<"
MANAGED_SOURCE_LINE='[ -f "$HOME/.ghostty-zsh-starship.zsh" ] && source "$HOME/.ghostty-zsh-starship.zsh"'

OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
ZSHRC_FILE="$HOME/.zshrc"

# 每项格式是「插件名:仓库地址」，插件名同时用作 clone 后的目录名
PLUGIN_REPOS=(
  "zsh-autosuggestions:https://github.com/zsh-users/zsh-autosuggestions"
  "zsh-syntax-highlighting:https://github.com/zsh-users/zsh-syntax-highlighting"
)

# ---------- 日志 ----------

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

# ---------- 帮助 ----------

usage() {
  cat <<EOF
Usage:
  ./$SCRIPT_NAME
  ./$SCRIPT_NAME --help

Behavior:
  Run without arguments to install Ghostty, Oh My Zsh, Starship, and Zsh plugins.

Notes:
  - macOS only
  - Homebrew must already be installed
  - This script is intended for a new Mac setup
  - ~/.zshrc only gets a small managed source block
  - Full shell config is written to ~/.ghostty-zsh-starship.zsh
EOF
}

# ---------- 前置检查 ----------
# 缺什么立刻报错退出，不要装到一半才发现

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "This script only supports macOS."
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Required command not found: $cmd"
    exit 1
  fi
}

require_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    log_error "Homebrew is required but not installed."
    log_error "Install Homebrew first, then rerun this script."
    exit 1
  fi
}

run_preflight_checks() {
  require_macos
  require_brew
  require_cmd curl
  require_cmd git
  require_cmd zsh
}

# ---------- 通用小工具 ----------

# 建出目标文件所在的父目录（已经存在也不会报错）
ensure_parent_dir() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
}

# ~/.zshrc 不存在就先建一个空文件，后面追加才有地方写
ensure_zshrc_exists() {
  if [[ ! -e "$ZSHRC_FILE" ]]; then
    : >"$ZSHRC_FILE"
  fi
}

# ---------- 解析插件清单 ----------
# PLUGIN_REPOS 每项是「名字:地址」，下面三个函数各取其中一段

plugin_name_from_entry() {
  local entry="$1"
  printf '%s\n' "${entry%%:*}"
}

plugin_repo_from_entry() {
  local entry="$1"
  printf '%s\n' "${entry#*:}"
}

plugin_dir_from_entry() {
  local entry="$1"
  local plugin_name

  plugin_name="$(plugin_name_from_entry "$entry")"
  printf '%s\n' "$OH_MY_ZSH_DIR/custom/plugins/$plugin_name"
}

# 生成 oh-my-zsh 的 plugins=(...) 那一行：
# 基础的 git 插件 + PLUGIN_REPOS 里列出的插件
plugin_line() {
  local entry
  local names=("git")
  local joined_names

  for entry in "${PLUGIN_REPOS[@]}"; do
    names+=("$(plugin_name_from_entry "$entry")")
  done

  joined_names="$(printf '%s ' "${names[@]}")"
  joined_names="${joined_names% }"
  printf 'plugins=(%s)\n' "$joined_names"
}

# ---------- 用 brew 装东西 ----------
# 统一先查再装：已装就跳过，保证脚本能重复执行

install_formula_if_missing() {
  local formula="$1"

  if brew list --formula "$formula" >/dev/null 2>&1; then
    log_info "Formula already installed: $formula"
    return 0
  fi

  log_info "Installing formula: $formula"
  brew install "$formula"
}

install_cask_if_missing() {
  local cask="$1"

  if brew list --cask "$cask" >/dev/null 2>&1; then
    log_info "Cask already installed: $cask"
    return 0
  fi

  log_info "Installing cask: $cask"
  brew install --cask "$cask"
}

# Ghostty 是 cask，Starship 是 formula
install_packages() {
  install_cask_if_missing ghostty
  install_formula_if_missing starship
}

# ---------- 安装 Oh My Zsh ----------
# 用官方脚本的无人值守模式，三个环境变量是关键：
#   RUNZSH=no      装完不要自动切进新 shell（脚本还要继续往下跑）
#   CHSH=no        不改默认 shell，保持系统现状
#   KEEP_ZSHRC=yes 不覆盖已有的 ~/.zshrc

install_oh_my_zsh() {
  log_info "Installing Oh My Zsh unattended"
  export RUNZSH=no
  export CHSH=no
  export KEEP_ZSHRC=yes
  export ZSH="$OH_MY_ZSH_DIR"

  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

# ---------- 安装 zsh 插件 ----------
# 直接 clone 到 oh-my-zsh 的 custom/plugins 目录下

install_plugins() {
  local entry
  local plugin_name
  local plugin_repo
  local plugin_dir

  for entry in "${PLUGIN_REPOS[@]}"; do
    plugin_name="$(plugin_name_from_entry "$entry")"
    plugin_repo="$(plugin_repo_from_entry "$entry")"
    plugin_dir="$(plugin_dir_from_entry "$entry")"

    if [[ -d "$plugin_dir" ]]; then
      log_info "Plugin already installed: $plugin_name"
      continue
    fi

    ensure_parent_dir "$plugin_dir"
    log_info "Installing plugin: $plugin_name"
    git clone "$plugin_repo" "$plugin_dir"
  done
}

# ---------- 写 shell 配置 ----------
# 完整配置单独放一个文件，方便以后手工查看和修改；
# 这些变量写成 \$HOME，是为了让它们在 zsh 启动时才展开，而不是现在展开。

write_managed_config() {
  ensure_parent_dir "$MANAGED_CONFIG_FILE"

  cat >"$MANAGED_CONFIG_FILE" <<EOF
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME=""
$(plugin_line)
source "\$ZSH/oh-my-zsh.sh"
eval "\$(starship init zsh)"
EOF
}

# 替换 .zshrc 里的受管块（先整段删掉旧的，再追加新的）：
# awk 一直在读，遇到 START 行开始丢，遇到 END 行停止丢，
# 于是夹在标记中间的内容全部被剔除。

rewrite_zshrc_managed_block() {
  local tmp_file

  ensure_zshrc_exists
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/ghostty-zsh-starship.XXXXXX")"

  awk -v start="$MANAGED_BLOCK_START" -v end="$MANAGED_BLOCK_END" '
    $0 == start { in_block = 1; next }
    $0 == end { in_block = 0; next }
    !in_block { print }
  ' "$ZSHRC_FILE" >"$tmp_file"

  mv "$tmp_file" "$ZSHRC_FILE"

  # 原文件末尾可能没换行，这里补一个，免得新块和旧内容粘在同一行
  if [[ -s "$ZSHRC_FILE" ]]; then
    printf '\n' >>"$ZSHRC_FILE"
  fi

  cat >>"$ZSHRC_FILE" <<EOF
$MANAGED_BLOCK_START
$MANAGED_SOURCE_LINE
$MANAGED_BLOCK_END
EOF
}

# ---------- 主流程 ----------

install_all() {
  run_preflight_checks
  install_packages
  install_oh_my_zsh
  install_plugins
  write_managed_config
  rewrite_zshrc_managed_block
  log_info "Install complete."
  log_info "Run 'exec zsh' or reopen the terminal to load Starship."
}

# 只支持一个参数：不给参数 = 安装，-h / --help / help = 看说明
main() {
  local command="${1:-install}"

  case "$command" in
    --help|-h|help)
      usage
      ;;
    install)
      install_all
      ;;
    *)
      log_error "Unknown argument: $command"
      usage
      exit 1
      ;;
  esac
}

main "$@"
