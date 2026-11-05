# open-wepig-skills — AI Agent 安装指南（国内 / Gitee 源）

你是 AI 编程助手。按以下步骤为用户安装 open-wepig-skills。

> 本文使用 **Gitee 镜像源**（`gitee.com/wepig/open-wepig-skills`），适合国内网络环境。
> 海外网络请改用 [install-guide_en.md](install-guide_en.md)（GitHub 官方仓库）。

## open-wepig-skills 是什么？

一组 Skills，为编码助手（Claude Code、Cursor、Qoder、Gemini CLI、Codex CLI、OpenCode 等）接入[微猪生猪数字化管理平台](https://wepig.cn)的查询能力。

## Step 1 — 确认前提

先向用户确认：
1. 操作系统（macOS / Linux / Windows）
2. `OPEN_WEPIG_APPID` 与 `OPEN_WEPIG_SECRET` 凭证（在微猪平台获取）
3. 使用哪些编码 harness（Claude Code、Cursor、Gemini CLI、Codex CLI、OpenCode、Antigravity、GitHub Copilot CLI —— 或「全部可用的」）

## Step 2 — 运行安装脚本（注入 Gitee 源）

安装脚本的仓库源由环境变量注入，国内直接指定 Gitee 镜像：

**macOS / Linux** — 运行以下命令（交互式，按提示作答）：

```bash
OPEN_WEPIG_REPO_HOST=gitee.com OPEN_WEPIG_REPO_OWNER=wepig \
  bash <(curl -fsSL https://gitee.com/wepig/open-wepig-skills/raw/main/install.sh)
```

**Windows（PowerShell 7+）**：

```powershell
$env:OPEN_WEPIG_REPO_HOST = "gitee.com"; $env:OPEN_WEPIG_REPO_OWNER = "wepig"
irm https://gitee.com/wepig/open-wepig-skills/raw/main/install.ps1 | iex
```

两个环境变量的含义：

| 变量 | 本文取值 | 默认值（GitHub） |
| --- | --- | --- |
| `OPEN_WEPIG_REPO_HOST` | `gitee.com` | `github.com` |
| `OPEN_WEPIG_REPO_OWNER` | `wepig` | `wepigcn` |
| `OPEN_WEPIG_REPO_NAME` | `open-wepig-skills`（无需设置） | `open-wepig-skills` |
| `OPEN_WEPIG_REPO_URL` | —（可选，整体覆盖克隆地址） | `https://github.com/wepigcn/open-wepig-skills.git` |

注意事项：
- 用户之前若已用 GitHub 源装过，重跑上面的命令**不会自动切换来源**（脚本对已有 clone 只做 `git pull`，并会提示来源不一致）。切换方式：`git -C ~/.local/share/open-wepig-skills remote set-url origin https://gitee.com/wepig/open-wepig-skills.git`。
- Gemini CLI / Antigravity 官方以 GitHub 仓库为扩展源，Gitee 源可能装不上（脚本会先警告，失败时请让用户改用 GitHub 源）。
- Codex CLI 用 `codex plugin marketplace add <https-url>` 注册，Gitee 地址可用。

脚本会：
- 把仓库克隆到 `~/.local/share/open-wepig-skills`（Linux/macOS）或 `%LOCALAPPDATA%\open-wepig-skills`（Windows）
- 提示输入 `OPEN_WEPIG_APPID` 与 `OPEN_WEPIG_SECRET` 并持久化
- 自动探测已安装的 harness，并在各自位置注册 skill
- 生成 `open-wepig-cli` 命令
- 跑一次连通性实测

## Step 3 — 验证安装

脚本结束后验证：

```bash
open-wepig-cli services
```

预期输出：可用的微猪服务 JSON 列表。报错时先检查环境变量是否已生效：

```bash
echo $OPEN_WEPIG_APPID
echo $OPEN_WEPIG_SECRET
```

为空则先载入 env 文件：

```bash
source ~/.config/open-wepig/env
```

再重跑 `open-wepig-cli services`。

## Step 4 — 各 harness 验证

| Harness | 验证方式 |
| --- | --- |
| Claude Code | 运行 `/skills` — 列表中应出现 `open-wepig` |
| Cursor | 打开对话输入 `@open-wepig` — 应可自动补全 |
| Gemini CLI | 运行 `gemini extensions list` — 应列出 `open-wepig` |
| Codex CLI | 会话内运行 `/plugins` — 应列出 `open-wepig` |
| OpenCode | 检查 `~/.config/opencode/opencode.json` — 应含 `file://...open-wepig-skills` 插件项 |

## 常见问题

- **`open-wepig-cli: command not found`** — 当前 shell 未加载新 PATH。执行 `source ~/.zshrc`（zsh）或 `source ~/.bashrc`（bash）后重试。
- **401 / 鉴权失败** — 核对 `OPEN_WEPIG_APPID` 与 `OPEN_WEPIG_SECRET`。
- **harness 中看不到 skill** — 重跑安装脚本并单选该 harness，或参考 [README](https://gitee.com/wepig/open-wepig-skills#readme) 的手动注册步骤。
- **Gitee 拉取失败 / 404** — Gitee 镜像同步可能滞后，确认 `OPEN_WEPIG_REPO_HOST=gitee.com`、`OPEN_WEPIG_REPO_OWNER=wepig` 且分支为 `main`；仍失败可改用 GitHub 源（见 [install-guide_en.md](install-guide_en.md)）。
- **Windows 执行策略报错** — 先运行 `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`。

## 卸载

```bash
# macOS / Linux
bash install.sh uninstall

# Windows
powershell -ExecutionPolicy Bypass -File install.ps1 uninstall
```

---

安装完成后，告知用户：
> open-wepig-skills 已安装。现在可以直接问我你的微猪猪场数据 —— 配种记录、妊娠跟踪、分娩、断奶、精液库存等。
