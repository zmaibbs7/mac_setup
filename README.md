# Mac setup

Mac 重装系统后的工作环境搭建：从一台空机器，到能拉代码、能跑 AI CLI 的终端。

## 目录

```
mac_setup/
├── setup.sh              统一入口，按顺序跑 01 → 04
├── 01-basic.sh           基本工具：Clash Verge + 微信输入法
├── 02-terminal.sh        终端环境：Ghostty + zsh + starship（需 Homebrew）
├── 03-apps.sh            常用软件：brew 批量安装
├── 04-ai-cli.sh          AI 命令行工具：安装 / 卸载
├── 05-setup-proxy.sh     代理配置：GitHub SSH 走 443 + 终端环境变量
├── packages/             离线安装包（dmg / zip）
└── README.md
```

## 快速开始

前提：macOS，且已装好 Homebrew（02 依赖它，01 不代装）。

1. 把离线包放进 `packages/`，文件名带版本号即可，脚本用通配匹配：

   ```
   packages/Clash.Verge_*.dmg
   packages/WeTypeInstaller*.zip
   ```

2. 打开终端，进入本目录并执行：

   ```bash
   cd ~/Project/mac_setup
   ./setup.sh
   ```

3. 中途会停一次：按提示手动配好 Clash（导入订阅、授权系统服务、打开系统代理），确认能上外网后按回车，剩下自动跑完。

## 分步执行

每一步都能单独跑，但顺序不能乱——01 离线可跑；02 起需要 Homebrew 与网络；03 在 02 的基础上批量装图形应用：

```bash
./01-basic.sh
./02-terminal.sh
./03-apps.sh
./04-ai-cli.sh
```

`05-setup-proxy.sh` 独立于以上流程，等 Clash 配好并运行后再执行：

```bash
./05-setup-proxy.sh
```

## 各步骤说明

| 脚本 | 做什么 | 装完的人工动作 | 前提 |
|---|---|---|---|
| 01-basic.sh | 从 `packages/` 装 Clash Verge 和微信输入法 | 打开 Clash 导入订阅、授权系统服务、开系统代理；输入法需注销重登后在列表里选用 | 无，离线可跑 |
| 02-terminal.sh | 装 Ghostty → 写 `~/.ghostty-zsh-starship.zsh` → 装 Oh My Zsh / Starship / 两个插件 → 在 `~/.zshrc` 追加受管 source 块 | 重开一个终端窗口 | Homebrew 已装 + 网络 |
| 03-apps.sh | 按 formula / cask 清单批量安装，已装的跳过 | 付费 App 激活 | Homebrew + 网络 |
| 04-ai-cli.sh | 交互式选工具（Claude Code / Codex / Pi），执行安装或卸载（卸载会清配置与缓存） | 各工具登录账号 | 网络 |
| 05-setup-proxy.sh | `~/.ssh/config` 加 GitHub 走 443；`~/.zshrc` 追加代理环境变量 | 重开终端或 `exec zsh` | Clash 运行中 + 7897 端口 |

## 03 的安装

```bash
./03-apps.sh          # 装缺失的，已装的跳过
```

脚本本身**没有 update 参数**，更新请直接用 Homebrew：

```bash
brew update && brew upgrade
brew upgrade --cask                    # 全部 cask
brew upgrade --cask keka               # 单个
```

新增软件：在 `03-apps.sh` 的 cask 区加一行 `install_cask 包名` 即可，不用改别的文件。

## 05 的代理配置

改两个文件，改前自动备份为 `*.bak.时间戳`，并用 `>>> ... <<<` 标记圈出受管段落，便于回滚：

- `~/.ssh/config`：新增 `Host github.com`，指向 `ssh.github.com:443`，`ProxyCommand` 走 `127.0.0.1:7897`
- `~/.zshrc`：追加 `http_proxy` / `https_proxy` / `all_proxy`（`socks5h`）及对应大写变量；`no_proxy` 已排除本机、内网和 OrbStack 域名

为什么走 443：部分网络环境下 GitHub 的 22 端口吞吐很差、甚至中途断连，443 是 GitHub 官方提供的备用入口。

验证（`exec zsh` 之后）：

```bash
env | grep -i _proxy
ssh -vT git@github.com 2>&1 | grep 'proxy command'            # 应出现 ssh.github.com 443
curl -s -o /dev/null -w '%{http_code}\n' https://github.com    # 期望 200
```

回滚：删掉 `~/.ssh/config` 与 `~/.zshrc` 里 `>>> ... <<<` 标记的段落即可。

## 注意

- **Clash** 首次启动要授权安装系统服务，会弹窗要密码，这一步只能人工点。
- **微信输入法** 装到 `/Library/Input Methods`，需要 sudo；装完不会立刻出现，注销重登后才能在输入法列表里选。
- **失败策略**：01 / 02 失败会中止（网络或终端环境没好，后面做了也没意义）；03 / 04 单项失败不影响其他项，最后统一汇总。所有脚本幂等，修好后重跑即可。
- **05 不在 `setup.sh` 里**，需要单独执行，且依赖 Clash 正在运行（混合端口 7897）。
- **Git 不跟踪空目录**：`packages/` 在放入安装包之前不会出现在提交里。
