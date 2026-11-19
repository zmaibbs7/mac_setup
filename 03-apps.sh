#!/usr/bin/env bash
# ============================================================
# Mac 软件清单 · Homebrew 批量安装脚本（第 2 步）
#
# 建议执行顺序：
#   1) ./install_ghostty_zsh_starship.sh   → Ghostty + Starship + Oh My Zsh + 插件
#   2) ./install_brew_soft.sh              → 本脚本：其余图形应用
#
# 职责边界（与第 1 步不重复）：
#   - 本脚本不安装 Homebrew（第 1 步的 require_brew 已保证 brew 存在）
#   - 本脚本不安装 Ghostty、Starship（第 1 步已装，且完成 zsh 配置）
#   - 本脚本只负责 uv + 图形应用类 cask
#
# 行为说明：
#   - 单个软件安装失败不会中断后续安装，最后统一汇总失败项
#   - 已安装的软件会跳过，可反复执行（幂等）
#   - 故意不使用 set -e：批量安装时希望「失败继续」，而不是第一个报错就全停
# ============================================================

FAILED=()

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

# ---------- 0. 前置检查 ----------
preflight() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_error "本脚本仅支持 macOS。"
    exit 1
  fi

  if ! command -v brew >/dev/null 2>&1; then
    # Apple Silicon 上 brew 不在默认 PATH 时，尝试从标准位置载入
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    else
      log_error "未找到 Homebrew。请先运行 install_ghostty_zsh_starship.sh 或 https://brew.sh 安装。"
      exit 1
    fi
  fi

  log_info "brew 就绪：$(command -v brew)"
}

# ---------- 安装辅助函数 ----------
install_formula() {
  local formula="$1"

  if brew list --formula "$formula" >/dev/null 2>&1; then
    log_info "已安装，跳过 formula：$formula"
    return 0
  fi

  log_info "安装 formula：$formula"
  if ! brew install "$formula"; then
    log_warn "安装失败：$formula"
    FAILED+=("formula:$formula")
  fi
}

install_cask() {
  local cask="$1"

  if brew list --cask "$cask" >/dev/null 2>&1; then
    log_info "已安装，跳过 cask：$cask"
    return 0
  fi

  log_info "安装 cask：$cask"
  if ! brew install --cask "$cask"; then
    log_warn "安装失败：$cask"
    FAILED+=("cask:$cask")
  fi
}

# ---------- 1. 命令行工具 ----------
# 说明：starship 已由第 1 步脚本安装并写入 zsh 配置，此处不再重复。
install_formulae() {
  # uv：Rust 写的超快 Python 包 / 环境管理器，可替代 pip、pyenv、pipx
  install_formula uv
}

# ---------- 2. 图形应用（cask）----------
install_casks() {

  # Chrome
  install_cask google-chrome

  # Futubull 富途牛牛：港股 / 美股行情与交易客户端
  install_cask futubull

  # IINA：基于 mpv 的视频播放器，字幕 / 画质处理强
  install_cask iina

  # Ice：菜单栏图标管理（隐藏 / 折叠状态栏图标），包名是 jordanbaird-ice
  install_cask jordanbaird-ice

  # OrbStack：Docker / Linux 虚拟机，比 Docker Desktop 轻量省电
  # 注意：若机器上已有 Docker Desktop，先卸载再装，避免 docker CLI 与 context 冲突
  install_cask orbstack

  # Visual Studio Code：微软代码编辑器
  install_cask visual-studio-code

  # Alcove：灵动岛风格胶囊工具（需 macOS 15+，付费软件需授权）
  # install_cask alcove

  # BetterDisplay：显示器分辨率 / HiDPI 调节（Pro 功能需授权）
  # install_cask betterdisplay

  # CC Switch：Claude Code 多套配置一键切换
  install_cask cc-switch

  # Keka：压缩 / 解压工具（支持 7z、rar 解压）
  install_cask keka

  # Notion：笔记 / 知识库
  install_cask notion

  # Snipaste：截图 + 贴图到屏幕
  install_cask snipaste

  # WeChat 微信：即时通讯
  install_cask wechat

  # 汽水音乐 SodaMusic：字节音乐客户端
  install_cask sodamusic

  # WorkBuddy AI：AI 助手（中文版是 workbuddy-cn，此处按英文版装）
  install_cask workbuddy-ai

  # DeepSeek Harness：DSH 桌面端
  install_cask deepseek-harness
}

# ---------- 3. 收尾 ----------

# 清掉隔离属性：以后双击打开 App 不再问「是从互联网下载的，确定打开吗」
# 对没有该属性的 App 是空操作，反复执行无副作用
strip_quarantine() {
  log_info "清理 /Applications 下 App 的隔离属性"
  xattr -dr com.apple.quarantine /Applications 2>/dev/null \
    || log_warn "个别 App 清理失败（通常是 root 所有），可忽略"
}

cleanup() {
  # 清理旧版本与安装缓存（可选）
  log_info "清理 Homebrew 缓存与旧版本"
  brew cleanup || log_warn "brew cleanup 未完成，可忽略"
}

print_summary() {
  if (( ${#FAILED[@]} == 0 )); then
    log_info "全部安装完成，无失败项。"
    log_info "提示：Ghostty / Starship 由第 1 步脚本负责，重开终端即可生效。"
    return 0
  fi

  log_warn "以下 ${#FAILED[@]} 项未能安装："
  printf '  - %s\n' "${FAILED[@]}"
  log_warn "常见原因与处理："
  log_warn "  1) /Applications 已存在同名 App（手动装过）：先退出并删除旧 App 再重试，"
  log_warn "     或用 brew install --cask --adopt <包名>（版本一致）/ --force（覆盖）。"
  log_warn "  2) 网络 / 代理问题：确认代理可用后单独重跑该项。"
  log_warn "  3) 单项重试示例：brew install --cask keka"
  return 1
}

main() {
  preflight

  # 只更新一次索引；随后关闭每次安装前的自动更新检查，提速
  log_info "更新 Homebrew 索引"
  brew update || log_warn "brew update 未完成，继续使用本地索引"
  export HOMEBREW_NO_AUTO_UPDATE=1

  install_formulae
  install_casks
  strip_quarantine   # 装完统一清一次，新装的 App 打开时不再弹「是否允许」
  cleanup

  print_summary
}

main "$@"
