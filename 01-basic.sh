#!/usr/bin/env bash
# ============================================================
# 01-basic.sh —— 基本工具
#
# 这一步装两个东西：
#   1. Clash Verge（代理客户端）—— 全自动，从 packages/ 里的 dmg 安装
#   2. 微信输入法                —— 自动解压并打开安装器，最后一步要人工点
#
# 装完之后必须人工配置（脚本结尾会再打印一遍）：
#   Clash ：导入订阅、授权系统服务、打开「系统代理」
#   输入法：安装器里点「安装」并输密码，之后注销重登才会生效
#
# 用法：./01-basic.sh
# 特点：可以反复执行，已经装过的会自动跳过。
# ============================================================

set -uo pipefail

# 切到脚本所在目录，保证 packages/ 这种相对路径找得到
cd "$(dirname "$0")" || exit 1

PKG_DIR="packages"                          # 离线安装包目录
CLASH_APP="/Applications/Clash Verge.app"   # Clash 装完应该在的位置
WETYPE_APP="/Library/Input Methods/WeType.app"
WETYPE_TMP="$HOME/.cache/mac-setup/wetype"  # 输入法安装器解压到这里

MOUNT_POINT=""   # 当前挂着的 dmg 卷，脚本退出时统一卸载

log()  { printf '[01] %s\n' "$*"; }
warn() { printf '[01][注意] %s\n' "$*"; }
err()  { printf '[01][错误] %s\n' "$*" >&2; }

# 不管脚本怎么退出，都别把 dmg 留在系统里
cleanup() {
  if [[ -n "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# 在 packages/ 里按名字找安装包；有多个版本时取最新的那个
find_pkg() {
  local pattern="$1" found
  found=$(ls -t "$PKG_DIR"/$pattern 2>/dev/null | head -1)
  if [[ -z "$found" ]]; then
    err "在 $PKG_DIR/ 里没找到 $pattern"
    return 1
  fi
  printf '%s\n' "$found"
}

# ---------- 1. Clash Verge（全自动） ----------
install_clash() {
  if [[ -d "$CLASH_APP" ]]; then
    log "Clash Verge 已经装过，跳过"
    return 0
  fi

  local dmg app
  dmg=$(find_pkg "Clash.Verge_*.dmg") || return 1

  log "挂载安装包：$(basename "$dmg")"
  MOUNT_POINT=$(hdiutil attach "$dmg" -nobrowse -readonly | grep -o '/Volumes/.*' | head -1)
  if [[ -z "$MOUNT_POINT" ]]; then
    err "挂载失败：$dmg"
    return 1
  fi

  # dmg 里一般只有一个 .app，直接找出来
  app=$(find "$MOUNT_POINT" -maxdepth 1 -name "*.app" -print -quit)
  if [[ -z "$app" ]]; then
    err "dmg 里没找到 .app"
    return 1
  fi

  log "复制 $(basename "$app") 到 /Applications"
  if ! cp -R "$app" /Applications/ 2>/dev/null; then
    log "需要管理员权限，请输入密码"
    sudo cp -R "$app" /Applications/ || { err "复制失败"; return 1; }
  fi

  hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  MOUNT_POINT=""

  if [[ -d "$CLASH_APP" ]]; then
    log "Clash Verge 安装完成"
  else
    err "装完了却没找到 $CLASH_APP"
    return 1
  fi
}

# ---------- 2. 微信输入法（解压 + 打开安装器） ----------
install_wetype() {
  if [[ -d "$WETYPE_APP" ]]; then
    log "微信输入法已经装过，跳过"
    return 0
  fi

  local zip
  zip=$(find_pkg "WeTypeInstaller*.zip") || return 1

  log "解压安装器：$(basename "$zip")"
  rm -rf "$WETYPE_TMP"
  mkdir -p "$WETYPE_TMP"
  if ! unzip -q "$zip" -d "$WETYPE_TMP"; then
    err "解压失败：$zip"
    return 1
  fi

  if [[ ! -d "$WETYPE_TMP/WeTypeInstaller.app" ]]; then
    err "解压后没找到 WeTypeInstaller.app"
    return 1
  fi

  # 这个包是个图形安装器，脚本只能把它打开；
  # 真正「点安装 + 输管理员密码」还是要人来点一下。
  log "打开安装窗口（需要在窗口里点「安装」）"
  open "$WETYPE_TMP/WeTypeInstaller.app"
}

# ---------- 3. 检查外网 ----------
# 配好 Clash 之后重新跑一次本脚本，就能用这个结果确认代理是否生效
check_network() {
  if curl -fsS -m 5 -o /dev/null https://www.gstatic.com/generate_204 2>/dev/null; then
    log "外网连接正常"
  else
    warn "现在还不能上外网，按下面的步骤配好 Clash 再跑一次本脚本验证"
  fi
}

# ---------- 4. 人工待办清单 ----------
print_manual_steps() {
  cat <<'EOF'

──────────────────────────────────────────────
 下面这些需要你手动做：

 【Clash Verge】
   1. 打开 Clash Verge，导入你的订阅
   2. 首次会要求安装系统服务，同意并输入密码
   3. 打开「系统代理」（要用 TUN 模式也一并打开）
   4. 浏览器能打开外网页面，就说明代理生效了

 【微信输入法】
   1. 在刚弹出的安装窗口里点「安装」，输入管理员密码
   2. 安装器要联网下载输入法本体，网络没通就先配好 Clash
   3. 装完到「系统设置 → 键盘 → 输入法」里添加
   4. 注销重登后才会出现在输入法列表里
──────────────────────────────────────────────
EOF
}

main() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    err "这个脚本只能在 macOS 上跑"
    exit 1
  fi

  if [[ ! -d "$PKG_DIR" ]]; then
    err "没找到 $PKG_DIR/ 目录，请把安装包放进去"
    exit 1
  fi

  log "开始安装基本工具"

  # Clash 是后续所有下载的前提，装不上就直接退出
  if ! install_clash; then
    print_manual_steps
    exit 1
  fi

  # 输入法失败不影响后面（brew 里也有），只提示
  install_wetype || warn "微信输入法没装成，修好后重新跑 ./01-basic.sh"

  check_network
  print_manual_steps
}

main "$@"
