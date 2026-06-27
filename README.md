# open-wepig-skills

中文 | [English](README_en.md)

给编码助手接入[微猪生猪数字化管理平台](https://wepig.cn) 查询能力的 [Skills](https://docs.claude.com/en/docs/claude-code/skills) 集合。

## 安装

### 方式一：一键脚本（推荐）

**让 AI 助手帮你安装** — 将以下提示词粘贴到 Claude Code、Cursor、Qoder 或任意 AI 编程助手中：

```
请按照以下安装指南，帮我安装 open-wepig-skills：
https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/docs/install-guide.md
```

AI 助手会读取安装指南、向你确认凭证和目标平台，然后自动完成整个安装流程。

**或者自己运行：**

**macOS / Linux：**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.sh)
```

**Windows（PowerShell）：**

```powershell
irm https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.ps1 | iex
```

### 方式二：Claude Code plugin marketplace

```text
/plugin marketplace add wepigcn/open-wepig-skills
/plugin install open-wepig@open-wepig-skills
```

> marketplace 安装只让 Claude Code 识别 skill，**仍需再跑一次方式一**配置鉴权。

### 方式三：手动 clone

**macOS / Linux：**

```bash
git clone https://github.com/wepigcn/open-wepig-skills.git ~/.local/share/open-wepig-skills
# 鉴权（写入 ~/.zshrc 持久化）
export OPEN_WEPIG_APPID=你的appid
export OPEN_WEPIG_SECRET=你的secret
# 直接用绝对路径调用，或跑一次 bash install.sh 生成 open-wepig-cli 命令
node ~/.local/share/open-wepig-skills/scripts/open-cli.mjs services
```

**Windows：**

```powershell
git clone https://github.com/wepigcn/open-wepig-skills.git $env:LOCALAPPDATA\open-wepig-skills
# 鉴权
$env:OPEN_WEPIG_APPID = "你的appid"
$env:OPEN_WEPIG_SECRET = "你的secret"
# 直接用绝对路径调用，或跑一次 install.ps1 生成 open-wepig-cli 命令
node $env:LOCALAPPDATA\open-wepig-skills\scripts\open-cli.mjs services
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
| **Codex CLI** | `codex marketplace add <repo>`（已含 `.agents/plugins/marketplace.json`），再 `/plugins` 安装 | marketplace 刷新 |
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
