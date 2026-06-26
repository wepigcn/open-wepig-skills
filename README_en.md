# open-wepig-skills

[中文](README.md) | English

A collection of [Skills](https://docs.claude.com/en/docs/claude-code/skills) that give coding assistants query capabilities for the [Wepig Pig digital management platform](https://wepig.cn).

## Installation

### Option 1: One-liner (recommended)

**macOS / Linux:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.sh)
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.ps1 | iex
```

### Project-level installation

By default, skills are installed to user-space directories (`~/.claude/skills`, `~/.cursor/skills`). To install into a specific project instead:

**macOS / Linux:**

```bash
bash install.sh install --project ./my-project
```

**Windows:**

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 install --project ./my-project
```

Project-level installation will:
- Link the Claude Code / Cursor skill into `.claude/skills` / `.cursor/skills` under the project directory.
- Create a project-level auth file: `.open-wepig.env` (Bash) or `.open-wepig.env.ps1` (PowerShell) in the project root.
- Install Copilot / Antigravity / Gemini / Codex / OpenCode globally (they are inherently global plugins) and print a notice.

### Option 2: Claude Code plugin marketplace

```text
/plugin marketplace add wepigcn/open-wepig-skills
/plugin install open-wepig@open-wepig-skills
```

> The marketplace install only lets Claude Code recognize the skill. You still need to run Option 1 to configure authentication.

### Option 3: Manual clone

**macOS / Linux:**

```bash
git clone https://github.com/wepigcn/open-wepig-skills.git ~/.local/share/open-wepig-skills
# Auth (persist in ~/.zshrc)
export OPEN_WEPIG_APPID=your_appid
export OPEN_WEPIG_SECRET=your_secret
# Call directly, or run bash install.sh to generate the open-wepig-cli command
node ~/.local/share/open-wepig-skills/scripts/open-cli.mjs services
```

**Windows:**

```powershell
git clone https://github.com/wepigcn/open-wepig-skills.git $env:LOCALAPPDATA\open-wepig-skills
# Auth
$env:OPEN_WEPIG_APPID = "your_appid"
$env:OPEN_WEPIG_SECRET = "your_secret"
# Call directly, or run install.ps1 to generate the open-wepig-cli command
node $env:LOCALAPPDATA\open-wepig-skills\scripts\open-cli.mjs services
```

## Harness support

`install.sh` / `install.ps1` auto-installs to selected harnesses; missing CLIs are skipped with manual instructions. After installation, all platforms use the `open-wepig-cli` command.

| Harness | Install command | Auto-update |
| --- | --- | --- |
| **Claude Code** | symlink/junction → `~/.claude/skills` | after `git pull` |
| **Cursor** | symlink/junction → `~/.cursor/skills` | after `git pull` |
| **GitHub Copilot CLI** | `copilot plugin marketplace add` + `install` | re-run install |
| **Antigravity** | `agy plugin install <repo>` | re-run to update |
| **Gemini CLI** | `gemini extensions install <repo>` (includes `gemini-extension.json`) | `gemini extensions update open-wepig` |
| **Codex CLI** | `codex marketplace add <repo>` (includes `.agents/plugins/marketplace.json`), then install via `/plugins` | marketplace refresh |
| **OpenCode** | writes `file://` plugin to `~/.config/opencode/opencode.json` (requires `jq` on macOS/Linux) | after `git pull` |

## Uninstall

**macOS / Linux:**

```bash
bash install.sh uninstall
```

**Windows:**

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 uninstall
```

> Plugin uninstall sub-commands (agy / gemini / codex) are attempted in compatibility mode; if the CLI uses a different sub-command name, manual confirmation may be needed.
