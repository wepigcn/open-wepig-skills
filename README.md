# open-wepig-skills

给编码助手接入[微猪生猪数字化管理平台](https://wepig.cn) 查询能力的 [Skills](https://docs.claude.com/en/docs/claude-code/skills) 集合。装好后，助手可调用 open-wepig 网关接口。

## 安装

### 方式一：一键脚本（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.sh | bash
```

或 clone 后运行：

```bash
git clone https://github.com/wepigcn/open-wepig-skills.git
cd open-wepig-skills
bash install.sh
```

完成后新开终端，即可在任意目录用 `open-wepig-cli services` 等命令。

### 方式二：Claude Code plugin marketplace

```text
/plugin marketplace add wepigcn/open-wepig-skills
/plugin install open-wepig@open-wepig-skills
```

> marketplace 安装只让 Claude Code 识别 skill，**仍需再跑一次方式一**配置鉴权与 `open-wepig-cli` 命令。

### 方式三：手动 clone

```bash
git clone https://github.com/wepigcn/open-wepig-skills.git ~/open-wepig-skills
# 鉴权（写入 ~/.zshrc 持久化）
export OPEN_WEPIG_APPID=你的appid
export OPEN_WEPIG_SECRET=你的secret
# 直接用绝对路径调用，或跑一次 bash install.sh 生成 open-wepig-cli 命令
node ~/open-wepig-skills/skills/open-wepig/scripts/wepig.mjs services
```

## 各平台自动安装/更新命令

`install.sh` 按所选 harness 自动执行；命令缺失时跳过并打印手动命令。安装完成后所有平台统一用 `open-wepig-cli` 命令。

| Harness | 自动安装命令 | 自动更新 |
| --- | --- | --- |
| **Claude Code** | symlink → `~/.claude/skills` | `git pull` 后自动 |
| **Cursor** | symlink → `~/.cursor/skills` | `git pull` 后自动 |
| **GitHub Copilot CLI** | `copilot plugin marketplace add` + `install` | 重跑 install |
| **Antigravity** | `agy plugin install <repo>` | 重跑即更新 |
| **Gemini CLI** | `gemini extensions install <repo>`（已含 `gemini-extension.json`） | `gemini extensions update open-wepig` |
| **Codex CLI** | `codex marketplace add <repo>`（已含 `.agents/plugins/marketplace.json`），再 `/plugins` 安装 | marketplace 刷新 |
| **OpenCode** | 写入 `~/.config/opencode/opencode.json` 的 `file://` plugin（需 `jq`） | `git pull` 后自动 |

## 验证

```bash
open-wepig-cli services
```

或在 harness 里对助手说「列出 open-wepig 有哪些 service」，应触发 `open-wepig` skill 并返回 service 列表。

## 更新

- 一键脚本：`bash install.sh update`（`git pull` + 刷新 `open-wepig-cli` 命令 + 各平台同步，鉴权保留）。
- 手动：`git -C ~/open-wepig-skills pull`。

## 卸载

```bash
bash install.sh uninstall
```

交互确认后自动删：`open-wepig-cli` 命令、各 harness symlink / plugin 注册、鉴权文件、shell 配置里的相关行（保留 `.bak` 备份）；clone 目录会单独询问是否删除。

> 各平台 plugin 卸载子命令（agy / gemini / codex）以兼容方式尝试，若该 CLI 的卸载子命令名不同，可能需手动确认。
