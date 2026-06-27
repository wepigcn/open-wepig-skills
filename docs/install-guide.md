# open-wepig-skills — AI Agent Install Guide

You are an AI coding assistant. Follow these steps to install open-wepig-skills for the user.

## What is open-wepig-skills?

A collection of Skills that give coding assistants (Claude Code, Cursor, Qoder, Gemini CLI, Codex CLI, OpenCode, etc.) query capabilities for the [Wepig Pig digital management platform](https://wepig.cn).

## Step 1 — Confirm prerequisites

Ask the user:
1. Their operating system (macOS / Linux / Windows)
2. Their `OPEN_WEPIG_APPID` and `OPEN_WEPIG_SECRET` credentials (they can get these from the Wepig platform)
3. Which coding harness(es) they use (Claude Code, Cursor, Gemini CLI, Codex CLI, OpenCode, Antigravity, GitHub Copilot CLI — or "all available")

## Step 2 — Run the install script

**macOS / Linux** — run this shell command (it is interactive; answer the prompts):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.sh)
```

**Windows (PowerShell)**:

```powershell
irm https://raw.githubusercontent.com/wepigcn/open-wepig-skills/main/install.ps1 | iex
```

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
