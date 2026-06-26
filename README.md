# open-wepig-skills

给编码助手接入 **open-wepig** 猪场养殖业务数据查询能力的 [Skills](https://docs.claude.com/en/docs/claude-code/skills) 集合。装好后，助手可调用 open-wepig 网关接口，回答配种、妊娠、分娩、断奶、动物档案、精液、流转、遗传、淘汰、考测、审计等养殖数据问题。

参考 [obra/superpowers](https://github.com/obra/superpowers) 的分发方式，提供**一键脚本**、**plugin marketplace**、**手动 clone** 三种安装形态，覆盖 Claude Code、Cursor、GitHub Copilot CLI、Antigravity、Gemini CLI、Codex CLI、OpenCode 七个 harness，并支持自动更新。所有 harness 统一通过 `open-wepig-cli` 命令调用，不依赖工作目录或平台根变量。

## 仓库结构

```
install.sh                       # 一键安装/更新脚本（生成 open-wepig-cli 命令）
gemini-extension.json            # Gemini CLI 扩展清单
GEMINI.md                        # Gemini CLI 扩展上下文
.claude-plugin/
  plugin.json                     # Claude 插件清单
  marketplace.json                # Claude marketplace 清单
.agents/plugins/
  marketplace.json                # Codex CLI marketplace 清单
skills/
  open-wepig/                     # 数据查询 skill
    SKILL.md
    references/
    scripts/wepig.mjs
```

## 安装

> **关键**：无论用哪种 harness，都需运行一次 `install.sh`——它负责交互式配置网关鉴权（必填）、生成 `open-wepig-cli` PATH 命令。harness 侧的 plugin/marketplace 安装只是让该助手识别 skill，实际调用靠 `open-wepig-cli` 命令。

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

脚本流程：

1. 提示输入 `OPEN_WEPIG_APPID`（**必填**，空值重问）
2. 提示输入 `OPEN_WEPIG_SECRET`（**必填**，不回显）
3. 写入 `~/.open-wepig.env`（权限 600）并注入 `~/.zshrc` / `~/.bashrc`
4. clone 或更新仓库到 `~/open-wepig-skills`
5. 生成 `open-wepig-cli` 命令到 `~/.local/bin` 并加入 PATH
6. 多选目标 harness 并自动安装（见下表）
7. 实测验证鉴权与连通性

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

## License

MIT
