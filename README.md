# open-wepig-skills

中文 | [English](README_en.md)

给编码助手接入[微猪生猪数字化管理平台](https://wepig.cn) 查询能力的 [Skills](https://docs.claude.com/en/docs/claude-code/skills) 集合。

## 安装

> 国内推荐使用 **Gitee 镜像**（`gitee.com/wepig/open-wepig-skills`）。海外网络可用 GitHub 官方仓库，见 [English README](README_en.md)。

### 方式一：一键脚本（推荐）

**让 AI 助手帮你安装** — 将以下提示词粘贴到 Claude Code、Cursor、Qoder 或任意 AI 编程助手中：

```
请按照以下安装指南，帮我安装 open-wepig-skills：
https://gitee.com/wepig/open-wepig-skills/raw/main/docs/install-guide.md
```

AI 助手会读取安装指南、向你确认凭证和目标平台，然后自动完成整个安装流程。

**或者自己运行：**

**macOS / Linux：**

```bash
OPEN_WEPIG_REPO_HOST=gitee.com OPEN_WEPIG_REPO_OWNER=wepig \
  bash <(curl -fsSL https://gitee.com/wepig/open-wepig-skills/raw/main/install.sh)
```

**Windows（PowerShell 7+）：**

```powershell
$env:OPEN_WEPIG_REPO_HOST = "gitee.com"; $env:OPEN_WEPIG_REPO_OWNER = "wepig"
irm https://gitee.com/wepig/open-wepig-skills/raw/main/install.ps1 | iex
```

脚本默认从 GitHub 官方仓库拉取；上面两个环境变量把仓库源切到 Gitee 镜像。可注入的变量：

| 变量 | 说明 | 默认值 |
| --- | --- | --- |
| `OPEN_WEPIG_REPO_HOST` | 仓库主机 | `github.com` |
| `OPEN_WEPIG_REPO_OWNER` | 仓库所有者 | `wepigcn` |
| `OPEN_WEPIG_REPO_NAME` | 仓库名 | `open-wepig-skills` |
| `OPEN_WEPIG_REPO_URL` | 整体覆盖克隆地址 | `https://<host>/<owner>/<name>.git` |

> 已从 GitHub 装过的用户重跑上面的命令**不会自动切换来源**（脚本只对已有 clone 执行 `git pull`，并会提示来源不一致）。要切换：`git -C ~/.local/share/open-wepig-skills remote set-url origin https://gitee.com/wepig/open-wepig-skills.git`。
> 另：Gemini CLI / Antigravity 官方以 GitHub 仓库为扩展源，用 Gitee 源安装可能失败（脚本会先给出提示）。

### 方式二：Claude Code plugin marketplace

```text
/plugin marketplace add https://gitee.com/wepig/open-wepig-skills.git
/plugin install open-wepig@open-wepig-skills
```

> marketplace 安装只让 Claude Code 识别 skill，**仍需再跑一次方式一**配置鉴权。
> 另外，仓库内的 `.claude-plugin/marketplace.json` 插件地址指向 GitHub 官方仓库；国内网络拉取失败时请改用方式一。

### 方式三：手动 clone

**macOS / Linux：**

```bash
git clone https://gitee.com/wepig/open-wepig-skills.git ~/.local/share/open-wepig-skills
# 鉴权（写入 ~/.zshrc 持久化）
export OPEN_WEPIG_APPID=你的appid
export OPEN_WEPIG_SECRET=你的secret
# 直接用绝对路径调用，或跑一次 bash install.sh 生成 open-wepig-cli 命令
node ~/.local/share/open-wepig-skills/bin/open-cli.mjs services
```

**Windows：**

```powershell
git clone https://gitee.com/wepig/open-wepig-skills.git $env:LOCALAPPDATA\open-wepig-skills
# 鉴权
$env:OPEN_WEPIG_APPID = "你的appid"
$env:OPEN_WEPIG_SECRET = "你的secret"
# 直接用绝对路径调用，或跑一次 install.ps1 生成 open-wepig-cli 命令
node $env:LOCALAPPDATA\open-wepig-skills\bin\open-cli.mjs services
```

## 各平台自动安装/更新命令

`install.sh` / `install.ps1` 按所选 harness 自动执行；命令缺失时跳过并打印手动命令。安装完成后所有平台统一用 `open-wepig-cli` 命令。

| Harness | 自动安装命令 | 自动更新 |
| --- | --- | --- |
| **Claude Code** | symlink/junction → `~/.claude/skills` | `git pull` 后自动 |
| **Cursor** | symlink/junction → `~/.cursor/skills` | `git pull` 后自动 |
| **GitHub Copilot CLI** | `copilot plugin marketplace add` + `install` | 重跑 install |
| **Antigravity** | `agy plugin install <repo>` | 重跑即更新 |
| **Gemini CLI** | `gemini extensions install <repo>`（已含 `gemini-extension.json`） | `gemini extensions update open-wepig` |
| **Codex CLI** | `codex plugin marketplace add <repo-or-https-url>`（已含 `.agents/plugins/marketplace.json`），再 `/plugins` 安装 | `codex plugin marketplace upgrade` |
| **OpenCode** | 写入 `~/.config/opencode/opencode.json` 的 `file://` plugin（macOS/Linux 需 `jq`） | `git pull` 后自动 |

## 卸载

**macOS / Linux：**

```bash
bash install.sh uninstall
```

**Windows：**

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 uninstall
```

> 各平台 plugin 卸载子命令（agy / gemini / codex）以兼容方式尝试，若该 CLI 的卸载子命令名不同，可能需手动确认。
