# Mac setup

Mac 重装系统后的工作环境搭建：从一台空机器，到能拉代码、能跑 AI CLI 的终端。

> 当前状态：目录骨架已建好，各脚本内容按本文说明逐步填充。

## 目录

```
Mac setup/
├── setup.sh           统一入口，按顺序跑下面四个
├── 01-basic.sh        基本工具：Clash Verge + 微信输入法
├── 02-terminal.sh     终端环境：Homebrew + Ghostty + zsh + starship
├── 03-apps.sh         常用软件：brew 批量安装 / 更新
├── 04-ai-cli.sh       AI 命令行工具：安装 / 卸载
├── packages/          离线安装包（dmg / pkg）
└── README.md
```

## 快速开始

1. 把离线包放进 `packages/`，文件名带版本号即可，脚本用通配匹配：

   ```
   packages/Clash.Verge-2.x.x.dmg
   packages/WeType-1.x.x.pkg
   ```

2. 打开终端，进入本目录并执行：

   ```bash
   cd ~/Project/"Mac setup"
   ./setup.sh
   ```

3. 中途会停一次：按提示手动配好 Clash（导入订阅、授权系统服务、打开系统代理），确认能上外网后按回车，剩下自动跑完。

## 分步执行

每一步都能单独跑，但顺序不能乱——02 之后都依赖网络，03 之后都依赖 Homebrew：

```bash
./01-basic.sh
./02-terminal.sh
./03-apps.sh
./04-ai-cli.sh
```

## 各步骤说明

| 脚本 | 做什么 | 装完的人工动作 | 前提 |
|---|---|---|---|
| 01-basic.sh | 从 `packages/` 装 Clash Verge 和微信输入法 | 打开 Clash 导入订阅、授权系统服务、开系统代理；输入法需注销重登后在列表里选用 | 无，离线可跑 |
| 02-terminal.sh | 确保 Homebrew 就绪 → 装 Ghostty → 装 zsh / oh-my-zsh / starship 及插件 → 写入 `~/.zshrc` | 重开一个终端窗口 | 网络 |
| 03-apps.sh | 按 cask / formula 清单批量安装，已装的跳过 | 付费 App 激活 | Homebrew + 网络 |
| 04-ai-cli.sh | 安装 / 卸载 Claude Code、Codex、Pi | 各工具登录账号 | 网络 |

## 03 的安装与更新

```bash
./03-apps.sh          # 安装：装缺失的，已装的跳过（默认行为）
./03-apps.sh update   # 更新：brew update + 升级已装软件
```

新增软件：在 `03-apps.sh` 的 cask 区加一行 `install_cask 包名` 即可，不用改别的文件。

## 注意

- **Clash** 首次启动要授权安装系统服务，会弹窗要密码，这一步只能人工点。
- **微信输入法** 装到 `/Library/Input Methods`，需要 sudo；装完不会立刻出现，注销重登后才能在输入法列表里选。
- **失败策略**：01 / 02 失败会中止（网络或终端环境没好，后面做了也没意义）；03 / 04 单项失败不影响其他项，最后统一汇总。所有脚本幂等，修好后重跑即可。
- **Git 不跟踪空目录**：`packages/` 在放入安装包之前不会出现在提交里。
