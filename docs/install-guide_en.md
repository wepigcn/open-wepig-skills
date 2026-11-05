# open-wepig-skills — AI Agent Install Guide (International / GitHub source)

You are an AI coding assistant. Follow these steps to install open-wepig-skills for the user.

> This guide uses the **GitHub upstream repository** (`github.com/wepigcn/open-wepig-skills`).
> Users in mainland China should use [install-guide.md](install-guide.md) instead (Gitee mirror).

## What is open-wepig-skills?

A collection of Skills that give coding assistants (Claude Code, Cursor, Qoder, Gemini CLI, Codex CLI, OpenCode, etc.) query capabilities for the [Wepig Pig digital management platform](https://wepig.cn).

## Step 1 — Confirm prerequisites

Ask the user:
1. Their operating system (macOS / Linux / Windows)
2. Their `OPEN_WEPIG_APPID` and `OPEN_WEPIG_SECRET` credentials (they can get these from the Wepig platform)
3. Which coding harness(es) they use (Claude Code, Cursor, Gemini CLI, Codex CLI, OpenCode, Antigravity, GitHub Copilot CLI — or "all available")

## Step 2 — Run the install script (GitHub source)

The repository source is injected through environment variables. For the international/GitHub source the defaults already point at GitHub, so no override is required; set them explicitly only if you want to pin the source:

**macOS / Linux** — run this shell command (it is interactive; answer the prompts):

```bash
OPEN_WEPIG_REPO_HOST=github.com OPEN_WEPIG_REPO_OWNER=wepigcn \
  bash <(curl -fsSL https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.sh)
```

**Windows (PowerShell 7+)**:

```powershell
$env:OPEN_WEPIG_REPO_HOST = "github.com"; $env:OPEN_WEPIG_REPO_OWNER = "wepigcn"
irm https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.ps1 | iex
```

Environment variables understood by both install scripts:

| Variable | This guide | Default |
| --- | --- | --- |
| `OPEN_WEPIG_REPO_HOST` | `github.com` | `github.com` |
| `OPEN_WEPIG_REPO_OWNER` | `wepigcn` | `wepigcn` |
| `OPEN_WEPIG_REPO_NAME` | `open-wepig-skills` (no need to set) | `open-wepig-skills` |
| `OPEN_WEPIG_REPO_URL` | — (optional, overrides the clone URL entirely) | `https://github.com/wepigcn/open-wepig-skills.git` |

The script will:
- Clone the repo to `~/.local/share/open-wepig-skills` (Linux/macOS) or `%LOCALAPPDATA%\open-wepig-skills` (Windows)
- Prompt for `OPEN_WEPIG_APPID` and `OPEN_WEPIG_SECRET`, then persist them
- Auto-detect installed harnesses and register the skill in each one
- Generate the `open-wepig-cli` wrapper command
- Run a connectivity test to verify the setup

## Step 3 — Verify the install

After the script finishes, verify with:

```bash
open-wepig-cli services
```

Expected output: a JSON list of available Wepig services. If you see an error, check that the env vars are set:

```bash
echo $OPEN_WEPIG_APPID
echo $OPEN_WEPIG_SECRET
```

If they are empty, source the env file:

```bash
source ~/.config/open-wepig/env
```

Then re-run `open-wepig-cli services`.

## Step 4 — Harness-specific verification

| Harness | How to verify |
| --- | --- |
| Claude Code | Run `/skills` — `open-wepig` should appear in the list |
| Cursor | Open a chat, type `@open-wepig` — it should autocomplete |
| Gemini CLI | Run `gemini extensions list` — `open-wepig` should be listed |
| Codex CLI | Run `/plugins` inside a session — `open-wepig` should be listed |
| OpenCode | Check `~/.config/opencode/opencode.json` — should contain a `file://...open-wepig-skills` plugin entry |

## Troubleshooting

- **`open-wepig-cli: command not found`** — Your shell may not have sourced the new PATH. Run `source ~/.zshrc` (zsh) or `source ~/.bashrc` (bash), then retry.
- **401 / auth errors** — Double-check `OPEN_WEPIG_APPID` and `OPEN_WEPIG_SECRET` are correct.
- **Skill not visible in harness** — Re-run the install script and select the specific harness, or follow the manual registration steps in the [README](https://github.com/wepigcn/open-wepig-skills#readme).
- **Clone fails / 404** — Confirm `OPEN_WEPIG_REPO_HOST=github.com` and `OPEN_WEPIG_REPO_OWNER=wepigcn`, and that the branch is `main`. If GitHub is unreachable, use the Gitee mirror guide instead ([install-guide.md](install-guide.md)).
- **Windows execution policy error** — Run `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` first.

## Uninstall

```bash
# macOS / Linux
bash install.sh uninstall

# Windows
powershell -ExecutionPolicy Bypass -File install.ps1 uninstall
```

---

Once installation is complete, tell the user:
> open-wepig-skills is installed. You can now ask me questions about your Wepig pig farm data — breeding records, pregnancy tracking, farrowing, weaning, semen inventory, and more.
