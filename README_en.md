# open-wepig-skills

[中文](README.md) | English

A collection of [Skills](https://docs.claude.com/en/docs/claude-code/skills) that give coding assistants query capabilities for the [Wepig Pig digital management platform](https://wepig.cn).

## Installation

### Option 1: One-liner (recommended)

**Let your AI agent install it** — paste this prompt into Claude Code, Cursor, Qoder, or any AI coding agent:

```
Please install open-wepig-skills by following the instructions here:
https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/docs/install-guide_en.md
```

The agent will read the install guide, confirm your credentials and target harness(es), and complete the full installation for you.

**Or run it yourself:**

**macOS / Linux:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.sh)
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.ps1 | iex
```

> The repository source is injected via environment variables; the defaults below already target the GitHub upstream. Users in mainland China can switch to the Gitee mirror with `OPEN_WEPIG_REPO_HOST=gitee.com OPEN_WEPIG_REPO_OWNER=wepig` (see [中文 README](README.md)).

| Variable | Meaning | Default |
| --- | --- | --- |
| `OPEN_WEPIG_REPO_HOST` | repository host | `github.com` |
| `OPEN_WEPIG_REPO_OWNER` | repository owner | `wepigcn` |
| `OPEN_WEPIG_REPO_NAME` | repository name | `open-wepig-skills` |
| `OPEN_WEPIG_REPO_URL` | overrides the whole clone URL | `https://<host>/<owner>/<name>.git` |

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
node ~/.local/share/open-wepig-skills/bin/open-cli.mjs services
```

**Windows:**

```powershell
git clone https://github.com/wepigcn/open-wepig-skills.git $env:LOCALAPPDATA\open-wepig-skills
# Auth
$env:OPEN_WEPIG_APPID = "your_appid"
$env:OPEN_WEPIG_SECRET = "your_secret"
# Call directly, or run install.ps1 to generate the open-wepig-cli command
node $env:LOCALAPPDATA\open-wepig-skills\bin\open-cli.mjs services
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
| **Codex CLI** | `codex plugin marketplace add <repo-or-https-url>` (includes `.agents/plugins/marketplace.json`), then install via `/plugins` | `codex plugin marketplace upgrade` |
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
