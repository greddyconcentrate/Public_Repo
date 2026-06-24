# Mac IDE Setup — Concentrate.ai Developer Environment
**Audience:** New interns and developers joining Concentrate.ai  
**Last updated:** June 2026  
**Maintained by:** Engineering team  
**Review status:** Pending CTO review

> Run `mac_ide_setup.sh` for an automated setup on a fresh Mac user account.  
> This document explains what the script does and covers manual setup for accounts where the script cannot run.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Running the Setup Script](#2-running-the-setup-script)
3. [What the Script Does](#3-what-the-script-does)
4. [Manual Setup Reference](#4-manual-setup-reference)
5. [The VM Launcher](#5-the-vm-launcher)
6. [IDE Configuration](#6-ide-configuration)
7. [Verification Checklist](#7-verification-checklist)
8. [Known Gotchas](#8-known-gotchas)

---

## 1. Prerequisites

Before running the script you need:

- A Mac with macOS and zsh (default on all modern Macs)
- Your Concentrate.ai API key — get this from the [Concentrate dashboard](https://concentrate.ai) after signing up with your company Google Workspace account. Keys start with `sk-cn-`.
- Your BlueLobster API key — get this from the [BlueLobster dashboard](https://bluelobster.ai).
- An internet connection (the script installs Homebrew, jq, and Zed if missing)

> **Note on Google Workspace:** Your `@concentrate.ai` Google account may not be ready on day one — ops/finance provisions it. You do not need it to get started. Sign up for Concentrate.ai with any email and get your API key immediately.

---

## 2. Running the Setup Script

The script is designed for a **fresh Mac user account** — one that has never been configured for development. If you have an existing `.zshrc`, the script will exit safely without touching anything.

**Step 1 — Download the script:**

```bash
curl -o ~/mac_ide_setup.sh https://raw.githubusercontent.com/greddyconcentrate/Public_Repo/main/mac_ide_setup.sh
```

**Step 2 — Make it executable:**

```bash
chmod +x ~/mac_ide_setup.sh
```

**Step 3 — Run it:**

```bash
~/mac_ide_setup.sh
```

The script will prompt you for your Concentrate API key and your email address (for the SSH key). Everything else is automatic.

**Step 4 — Activate your configuration:**

When the script finishes, run:

```bash
source ~/.zshrc
```

> Do not just close and reopen your terminal — that may not be sufficient. Run `source ~/.zshrc` explicitly.

---

## 3. What the Script Does

In order:

1. **Checks for existing `.zshrc`** — if found, exits without changes. You must configure manually (see Section 4) or use a fresh account.
2. **Creates `~/.secrets`** — prompts for your Concentrate API key and writes it. If `.secrets` already exists but doesn't contain `CONCENTRATE_API_KEY`, appends safely. Never overwrites an existing key.
3. **Adds BlueLobster API key to `~/.secrets`** — prompts for your BL key and appends it. Skips if already present.
4. **Creates `~/.zshrc`** — standard Concentrate configuration (see Section 4 for contents).
5. **Installs Homebrew** — if not already installed. Handles both Intel and Apple Silicon Macs.
6. **Installs jq** — required by the VM manager to parse API responses.
7. **Generates an RSA SSH key** — at `~/.ssh/id_rsa`. BlueLobster VMs require RSA; Ed25519 is not supported.
8. **Adds SSH key to Mac keychain** — so you never type a passphrase again.
9. **Creates `~/scripts/` and `~/dev_projects/`** — standard working directories.
10. **Writes `~/scripts/concentrate.sh`** — the BlueLobster VM manager (see Section 5).
11. **Writes `~/.config/zed/settings.json`** — Zed AI configuration with Concentrate as the model provider (see Section 6). Skips if the file already exists.

---

## 4. Manual Setup Reference

Use this section if the script cannot run on your account (existing `.zshrc`).

### 4.1 `~/.secrets`

Never commit this file to Git.

```zsh
# ~/.secrets
# API keys — never commit this file to Git

# Concentrate.ai
export CONCENTRATE_API_KEY="sk-cn-YOUR_KEY_HERE"

# BlueLobster (optional — only needed for VM launcher)
# export BLUE_LOBSTER_API_KEY="YOUR_BL_KEY_HERE"
```

### 4.2 `~/.zshrc`

Add these lines. If `.zshrc` already has content, append carefully — one bad line can break every terminal launch.

```zsh
# Load SSH key into agent (silent — only prompts once ever)
ssh-add --apple-use-keychain ~/.ssh/id_rsa 2>/dev/null

# Load API keys
source ~/.secrets

# ── Aliases ──────────────────────────────────────────────────────────────────
alias myconfig="cat ~/.zshrc"
alias mykeys="printenv | grep -E '(API_KEY|BASE_URL|MODEL)'"
alias concentrate='~/scripts/concentrate.sh'

# ── Claude Code — route to Concentrate ───────────────────────────────────────
export ANTHROPIC_AUTH_TOKEN="$CONCENTRATE_API_KEY"
export ANTHROPIC_BASE_URL="https://api.concentrate.ai"
export ANTHROPIC_DEFAULT_OPUS_MODEL="minimax-m2-7-highspeed"
export ANTHROPIC_MODEL="opus"

# ── Land in working directory ─────────────────────────────────────────────────
cd ~/dev_projects 2>/dev/null || true
```

### 4.3 SSH Key

BlueLobster requires RSA. Generate with:

```bash
ssh-keygen -t rsa -b 4096 -C "your@email.com" -f ~/.ssh/id_rsa
```

Add to Mac keychain:

```bash
ssh-add --apple-use-keychain ~/.ssh/id_rsa
```

Display your public key to copy to BlueLobster:

```bash
cat ~/.ssh/id_rsa.pub
```

---

## 5. The VM Manager (concentrate.sh)

`~/scripts/concentrate.sh` is your main tool for connecting to and managing BlueLobster VMs. Run it via the `concentrate` alias, or it launches automatically when you open a new terminal.

### Requirements

- `BLUE_LOBSTER_API_KEY` must be in `~/.secrets`
- `jq` must be installed (the setup script handles this)
- Zed must be installed

### BlueLobster API key

The setup script prompts for your BlueLobster API key and writes it to `~/.secrets` automatically. If you need to update it later:

```bash
open -a TextEdit ~/.secrets
```

### How it works

When you run `concentrate`, a persistent menu appears in your terminal window showing all your BlueLobster VMs with live status indicators:

```
  🦞 BlueLobster VM Manager
  ─────────────────────────────────────────────

  1)  my-vm-name            🟢 running    38.29.145.235
  2)  another-vm            🔴 stopped   38.29.145.238

  r)  Refresh
  q)  Quit
```

Select a VM by number to open its sub-menu:

```
  🦞 🟢  my-vm-name  (running)
  ─────────────────────────────────────────────

  1)  Connect        (open SSH + Zed in new window)
  2)  Git Sync       (pull + push, no SSH change)
  3)  Shut Down      (optional git sync, then power off)

  b)  Back
```

### Connect flow

1. If the VM is stopped, powers it on and waits until running
2. Opens a **new terminal window** for the SSH session
3. New window: git pulls latest on the VM, opens Zed connected to `~/dev_projects` on the VM, drops into interactive SSH
4. Main menu window stays open — this is your control panel
5. When you exit the SSH session, the new terminal window closes automatically

> The main menu window is intentional. It is a visual reminder that your VM is running. Manage Git and shutdown from there before closing your terminal.

### Git Sync

Runs `git pull` on the VM, then prompts whether to push. No SSH session change — runs non-interactively over SSH and returns to the sub-menu.

### Shut Down

Prompts whether to Git Sync first, then sends a shutdown request to the BlueLobster API. The menu updates to show the VM as stopped.

### Quit

If any VMs are still running, warns you and asks to confirm before exiting. Returns you to the Mac terminal prompt.

---

## 6. Zed AI Configuration

The setup script writes `~/.config/zed/settings.json` with Concentrate defaults. **No manual steps required** — Claude Agent and the Concentrate LLM provider configure themselves automatically when Zed first launches.

### What you get out of the box

When you open Zed after running the setup script:

- **Claude Agent** appears in the Agent Panel dropdown (right sidebar) — select it
- **MiniMax M2 (Concentrate)** is the default model
- **Claude Sonnet 4.6 (Concentrate)** is available in the model dropdown
- No Zed subscription required — everything routes through your Concentrate API key

### What the script configures automatically

| Setting | Value |
|---|---|
| Default model | MiniMax M2 (Concentrate) |
| Second model available | Claude Sonnet 4.6 (Concentrate) |
| Agent panel | Right sidebar |
| All other panels | Left sidebar |
| Theme | One Dark |
| Font sizes | UI: 16, Buffer: 15 |
| Telemetry | Diagnostics only, metrics off |

### If `settings.json` already exists

The script skips writing it to avoid overwriting existing configuration. Apply the Concentrate defaults manually by copying the relevant blocks from the reference config in this section into your existing `settings.json`.

Reference config to merge in:

```json
"agent_servers": {
  "claude-acp": {
    "type": "registry"
  }
},
"agent": {
  "default_profile": "minimal",
  "default_model": {
    "provider": "openai",
    "model": "minimax-m2-7-highspeed"
  },
  "dock": "right"
},
"language_models": {
  "openai_compatible": {
    "Concentrate": {
      "api_url": "https://api.concentrate.ai",
      "available_models": [
        {
          "name": "minimax-m2-7-highspeed",
          "display_name": "MiniMax M2 (Concentrate)",
          "max_tokens": 128000
        },
        {
          "name": "claude-sonnet-4-6",
          "display_name": "Claude Sonnet 4.6 (Concentrate)",
          "max_tokens": 16000
        }
      ]
    }
  }
}
```

### VS Code

> **Placeholder** — VS Code setup with remote SSH and Concentrate routing to be documented.

### JetBrains IDEs

> **Placeholder** — JetBrains Gateway setup with remote SSH to be documented.

---

## 7. Verification Checklist

After running the script and `source ~/.zshrc`:

```
[ ] source ~/.zshrc ran without errors
[ ] mykeys alias shows CONCENTRATE_API_KEY and ANTHROPIC_BASE_URL
[ ] SSH key exists: ls ~/.ssh/id_rsa
[ ] ~/scripts/concentrate.sh exists and is executable
[ ] ~/dev_projects/ exists
[ ] concentrate alias resolves: which concentrate
[ ] Zed installed: zed --version
[ ] ~/.config/zed/settings.json exists
```

If you have a BlueLobster key:

```
[ ] BLUE_LOBSTER_API_KEY in ~/.secrets
[ ] concentrate command shows VM list
[ ] Connect opens a new terminal window with SSH + Zed
[ ] Main menu stays live while connected
[ ] Shut Down prompts for git sync then powers off VM
```

After opening Zed:

```
[ ] Claude Agent appears in Agent Panel dropdown (right sidebar)
[ ] MiniMax M2 (Concentrate) appears in model dropdown
[ ] Claude Sonnet 4.6 (Concentrate) appears in model dropdown
[ ] Sending a test prompt works without a Zed subscription prompt
```

---

## 8. Known Gotchas

### Don't launch Zed from the Dock
The Dock launches apps without sourcing `.zshrc`. Your API keys won't load and Claude Code will fail or fall back unexpectedly. Always use the `concentrate` command or launch from a terminal.

### `source ~/.zshrc` is not the same as reopening a terminal
After the setup script runs, you must explicitly run `source ~/.zshrc`. Closing and reopening a terminal window *usually* works but is not guaranteed depending on your terminal app settings.

### BlueLobster requires RSA keys
Modern SSH defaults to Ed25519. BlueLobster does not accept Ed25519. The script generates RSA explicitly. If you already have an Ed25519 key at `~/.ssh/id_ed25519`, it will not work with BlueLobster — generate a separate RSA key as described in Section 4.3.

### Editing `.secrets` and `.zshrc`
Use TextEdit, not Zed. Zed treats these as project files and may apply formatting that corrupts plain shell scripts.

```bash
open -a TextEdit ~/.secrets
open -a TextEdit ~/.zshrc
```

### New terminal windows don't re-launch the VM manager
When `concentrate` opens a new terminal for SSH, it creates a temp flag file that tells `.zshrc` to skip auto-launching the app in that window. This is intentional — you manage everything from the main menu window.

### VM is still running after closing the SSH window
Closing the SSH terminal window drops the connection but does not shut down the VM. Return to the main menu window and use **Shut Down** from the VM sub-menu, or log into the [BlueLobster dashboard](https://bluelobster.ai) and shut down manually.

### Zed `settings.json` not written
If `~/.config/zed/settings.json` already existed when the script ran, it was skipped. Apply the config manually using the reference block in Section 6.
