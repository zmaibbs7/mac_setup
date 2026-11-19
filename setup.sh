#!/usr/bin/env bash
# ============================================================
# Mac setup · 统一入口
#
#   依次执行：01-basic → 02-terminal → 03-apps → 04-ai-cli
#
# 用法：
#   ./setup.sh        执行全部步骤
#   ./setup.sh -h     显示说明
#
# 失败策略：
#   01 / 02  失败即中止（没网络、没终端环境，后面做了也白做）
#   03 / 04  单项失败不影响其他项，继续往下走，最后汇总
#
# 每一步也可以单独执行，例如：./03-apps.sh
# 所有脚本都是幂等的，失败后修好重跑即可。
# ============================================================

set -uo pipefail

cd "$(dirname "$0")" || exit 1

FAILED=()

info() { printf '\n==> %s\n' "$*"; }
ok()   { printf '    ✓ %s\n' "$*"; }
warn() { printf '    ! %s\n' "$*"; }
err()  { printf '    ✗ %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Mac setup · 统一入口

用法：
  ./setup.sh        依次执行 01 → 02 → 03 → 04
  ./setup.sh -h     显示本说明

步骤：
  01-basic.sh      基本工具：Clash Verge + 微信输入法（装完需人工配置）
  02-terminal.sh   终端环境：Homebrew + Ghostty + zsh + starship
  03-apps.sh       常用软件：brew 批量安装（./03-apps.sh update 为更新）
  04-ai-cli.sh     AI 命令行工具：安装 / 卸载

也可以跳过本入口，单独执行某一步。
EOF
}

# 01 装完要人工配好代理，后续步骤才有网
pause_for_manual_setup() {
  cat <<'EOF'

──────────────────────────────────────────────
 01 已装好，接下来需要你手动配置（约 3 分钟）：

   1) 打开 Clash Verge，导入你的订阅
   2) 首次会要求授权安装系统服务，同意并输入密码
   3) 打开「系统代理」（需要 TUN 模式的话也打开）
   4) 浏览器能打开外网页面，说明代理已生效

 配好后回到终端按回车，继续装终端环境。
──────────────────────────────────────────────
EOF
  read -r _ || true
}

# 步骤清单：脚本名|说明|失败策略（fatal = 中止，continue = 继续）
STEPS=(
  "01-basic.sh|基本工具（Clash Verge + 微信输入法）|fatal"
  "02-terminal.sh|终端环境（Homebrew + Ghostty + zsh + starship）|fatal"
  "03-apps.sh|常用软件（brew 批量安装）|continue"
  "04-ai-cli.sh|AI 命令行工具（安装 / 卸载）|continue"
)

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    "") ;;
    *) err "未知参数：$1"; usage; exit 2 ;;
  esac

  if [[ "$(uname -s)" != "Darwin" ]]; then
    err "本脚本仅支持 macOS。"
    exit 1
  fi

  local total=${#STEPS[@]} i=0 entry file desc policy

  for entry in "${STEPS[@]}"; do
    i=$((i + 1))
    IFS='|' read -r file desc policy <<< "$entry"
    info "[$i/$total] $desc"

    if [[ ! -f "$file" ]]; then
      warn "跳过：未找到 $file"
      FAILED+=("$desc（缺文件）")
      continue
    fi

    if bash "$file"; then
      ok "完成"
    else
      FAILED+=("$desc")
      if [[ "$policy" == "fatal" ]]; then
        err "中止。修好后重新运行 ./setup.sh 即可（已完成的步骤会自动跳过）"
        exit 1
      fi
      warn "未完全成功，继续执行下一步；可稍后单独重跑 ./$file"
    fi

    if [[ "$file" == "01-basic.sh" ]]; then
      pause_for_manual_setup
    fi
  done

  printf '\n──────────────────────────────────────────────\n'

  if (( ${#FAILED[@]} == 0 )); then
    ok "全部完成。"
    printf '    建议重开一个终端窗口，让 zsh / starship 生效；\n'
    printf '    装了微信输入法的话，注销重登后在输入法列表里选用。\n'
    return 0
  fi

  warn "以下步骤未完全成功："
  printf '      - %s\n' "${FAILED[@]}"
  printf '    修好后单独重跑对应脚本即可。\n'
  return 1
}

main "$@"
