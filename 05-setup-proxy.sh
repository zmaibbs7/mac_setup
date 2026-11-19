#!/usr/bin/env bash
#
# 一键配置 macOS 代理（配合 Clash 混合端口）
#   1. GitHub 的 SSH 改走 443（绕过 22 端口慢/断的问题）
#   2. 终端命令行（Ghostty 等）通过环境变量走代理
#
# 用法: bash setup-proxy.sh
# 特性: 可重复执行，结果一致；改动前自动备份
#
set -euo pipefail

PROXY_HOST=127.0.0.1
PROXY_PORT=7897
PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"
NO_PROXY_LIST="127.0.0.1,localhost,::1,*.local,*.orb.local,host.docker.internal,host.orb.internal,192.168.0.0/16,10.0.0.0/8,172.16.0.0/12"
SSH_CONFIG="$HOME/.ssh/config"
ZSHRC="$HOME/.zshrc"
STAMP="$(date +%Y%m%d-%H%M%S)"

# 备份文件（保留原文件名 + 时间戳）
backup() {
  if [ -f "$1" ]; then
    cp "$1" "$1.bak.$STAMP"
    echo "  备份 -> $1.bak.$STAMP"
  fi
}

# ============================================================
# 1. SSH：GitHub 走代理 443
# ============================================================
echo "[1/2] 配置 SSH：github.com -> ssh.github.com:443"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
backup "$SSH_CONFIG"
touch "$SSH_CONFIG"

# 先删掉旧的 Host github.com 段（含上次生成的标记），保证可重复执行
awk '
  /^# >>> github-ssh >>>/ { skip = 1; next }
  /^# <<< github-ssh <<</ { skip = 0; next }
  /^Host[[:space:]]/      { skip = ($2 == "github.com") }
  !skip
' "$SSH_CONFIG" > "$SSH_CONFIG.tmp"
mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"

# 确保文件以换行结尾，避免新段落粘到最后一行
if [ -s "$SSH_CONFIG" ] && [ -n "$(tail -c 1 "$SSH_CONFIG")" ]; then
  echo "" >> "$SSH_CONFIG"
fi

# 写入新配置
cat >> "$SSH_CONFIG" <<EOF
# >>> github-ssh >>>
Host github.com
    HostName ssh.github.com
    Port 443
    HostKeyAlias github.com
    User git
    ProxyCommand nc -X connect -x ${PROXY_HOST}:${PROXY_PORT} %h %p
# <<< github-ssh <<<
EOF

chmod 600 "$SSH_CONFIG"
echo "  已写入 $SSH_CONFIG"

# ============================================================
# 2. zsh：终端命令行走代理
# ============================================================
echo "[2/2] 配置 zsh 环境变量：${PROXY_HOST}:${PROXY_PORT}"

# 已有配置就跳过（幂等）
if grep -q '# >>> proxy >>>' "$ZSHRC" 2>/dev/null; then
  echo "  已存在，跳过 $ZSHRC"
else
  backup "$ZSHRC"
  {
    echo ""
    echo "# >>> proxy >>>"
    echo "export http_proxy=\"$PROXY_URL\""
    echo "export https_proxy=\"$PROXY_URL\""
    echo "export all_proxy=\"socks5h://${PROXY_HOST}:${PROXY_PORT}\""
    echo "export HTTP_PROXY=\"$PROXY_URL\""
    echo "export HTTPS_PROXY=\"$PROXY_URL\""
    echo "export ALL_PROXY=\"socks5h://${PROXY_HOST}:${PROXY_PORT}\""
    echo "export no_proxy=\"$NO_PROXY_LIST\""
    echo "export NO_PROXY=\"$NO_PROXY_LIST\""
    echo "# <<< proxy <<<"
  } >> "$ZSHRC"
  echo "  已写入 $ZSHRC"
fi

# ============================================================
# 完成
# ============================================================
cat <<EOF

完成。执行以下命令生效并验证：

  exec zsh
  env | grep -i _proxy
  ssh -vT git@github.com 2>&1 | grep 'proxy command'
  curl -sI https://github.com | head -1

回滚：删掉 ~/.ssh/config 与 ~/.zshrc 里 >>> ... <<< 标记的段落。
EOF
