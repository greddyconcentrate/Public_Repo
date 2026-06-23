# Concentrate.ai — VM Setup Guide

**Audience:** New interns and developers joining Concentrate.ai
**Last updated:** June 2026
**Maintained by:** Engineering team

This guide walks you through setting up your Linux development environment on a Blue Lobster VM from scratch. Follow it top to bottom. Do not skip ahead.

By the end you will have:
- A running Ubuntu 22.04 VM on Blue Lobster
- Your Concentrate API key configured and routing Claude Code through Concentrate
- Claude Code CLI installed and working
- Git configured and connected to GitHub
- A standard working directory at `~/dev_projects`

---

## Before You Begin

### Step 0.1 — Create a dedicated Mac user account

Do not run this setup under your existing Mac user account. The setup process writes environment variables and shell configuration specific to Concentrate.ai into your home directory. Mixing this into a personal environment causes conflicts.

**Create a fresh macOS user account first:**

1. Open **System Settings** → **Users & Groups**
2. Click **Add Account** (unlock with your password if prompted)
3. Set account type to **Administrator**
4. Name it something work-specific (e.g. `concentrate` or your first name)
5. Log out of your personal account and log in to the new one

> If this is a Concentrate-provided Mac, skip this — your machine is already a clean environment.

### Step 0.2 — iCloud Drive

When you log into your new account you may be prompted to sign into iCloud. You can sign in for App Store access. **Do not enable iCloud Drive.** iCloud Drive syncs your Desktop and Documents folders to Apple's servers, which conflicts with your development environment and risks syncing work files you do not want synced.

When prompted: sign into iCloud if you want, but toggle **iCloud Drive off**.

### Step 0.3 — What you need before starting

Have all of these ready before running anything:

| What | Where to get it |
|------|----------------|
| Concentrate API key (`sk-cn-...`) | [concentrate.ai](https://concentrate.ai) → Dashboard → API Keys |
| Blue Lobster account | [bluelobster.ai](https://bluelobster.ai) — log in with your `@concentrate.ai` Google account |
| GitHub account | Your own personal GitHub account |

**Concentrate API key:** The setup script's first step prompts you for this. Go get it now if you do not have it.

**GitHub:** Use your personal GitHub account — not a company one. This lets you keep your work and build a portfolio after the internship ends.

**API key safety:** Never commit your API key to a git repo. Never put it in a project folder. The script stores it in `~/.secrets`, which lives in your home directory outside any repo.

---

## Part 1 — Generate an SSH Key on Your Mac

You need an SSH key on your Mac to authenticate to your Blue Lobster VM. Generate the key here, then paste the public half into Blue Lobster when creating the VM.

> **Important:** Blue Lobster does not support Ed25519 keys. You must use RSA. Use the command below exactly as written.

Open a terminal and check whether you already have an RSA key:

```bash
ls ~/.ssh/id_rsa.pub
```

- **File exists** — you already have a key. Skip to Part 2.
- **"No such file or directory"** — generate one now:

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

When prompted:
- **Save location:** press Enter to accept the default (`~/.ssh/id_rsa`)
- **Passphrase:** set one — do not leave it empty

Display your public key — you will paste this into Blue Lobster in the next step:

```bash
cat ~/.ssh/id_rsa.pub
```

Copy the entire output line. It starts with `ssh-rsa` and ends with your email. Keep this terminal open.

---

## Part 2 — Create Your Blue Lobster VM

1. Go to [bluelobster.ai](https://bluelobster.ai)
2. Log in with your `@concentrate.ai` Google Workspace account
3. Click **Instances** → **+ Create Instance**
4. Configure the instance:

| Setting | Value |
|---------|-------|
| Processor | `v1_cpu_small` (or `nano` for lighter workloads) |
| OS | Ubuntu 22.04 |
| Machine name | Whatever you like — just a dashboard label |
| Username | Whatever you want — pick one and use it consistently across all your VMs |

5. Paste your public key from `cat ~/.ssh/id_rsa.pub` when prompted

> **Important:** When pasting your public key, make sure there are no leading or trailing spaces. Blue Lobster is strict about this — extra whitespace will cause your SSH connection to fail.

6. Click **Create Instance**

Wait for status to show **running** before continuing.

> **Note:** Blue Lobster is currently in BETA. Back up your work regularly — do not treat the VM as permanent storage.

---

## Part 3 — Connect to Your VM

Find your VM's IP address in the Blue Lobster dashboard (shown next to your instance).

In your Mac terminal:

```bash
ssh [username]@[Blue_Lobster_IP]
```

For example: `ssh admin@38.29.145.238`

- Type `yes` when asked about the host fingerprint — expected on first connection
- If prompted for a password instead of connecting directly, your SSH key was not injected correctly. Delete the VM, reprovision it, and paste the public key carefully with no leading or trailing spaces.

**Optional but recommended — store your passphrase in Mac Keychain:**

```bash
ssh-add --apple-use-keychain ~/.ssh/id_rsa
```

You are now inside your VM. All commands from this point run on the VM unless noted otherwise.

---

## Part 4 — Run the Setup Script

The setup script handles everything from here: API key config, shell setup, git, Node.js, and Claude Code.

Run these two commands — **do not combine them into one**. The first downloads the script. The second runs it interactively so you can respond to each prompt.

```bash
curl -fsSL https://raw.githubusercontent.com/greddyconcentrate/Public_Repo/main/vm_setup.sh -o vm_setup.sh
```

```bash
bash vm_setup.sh
```

> **Why two steps?** Running `curl | bash` directly pipes the script into a non-interactive shell, which causes all prompts to be skipped silently. Always download first, then run.

The script will walk you through five steps. Here is what each step does and what to expect.

---

### Script Step 1 — Concentrate API Key

```
STEP 1: Concentrate API Key
Enter your Concentrate API key (starts with sk-cn-): █
```

Paste your `sk-cn-...` key when prompted. The script writes it to `~/.secrets` along with model configuration. This file is sourced every time you open a terminal so your credentials are always available.

---

### Script Step 2 — Shell Configuration

No input required. The script patches `~/.bashrc` to source `~/.secrets` on every login and adds the npm global binary path needed for Claude Code.

```
STEP 2: Shell configuration
✅ ~/.bashrc updated to source ~/.secrets.
✅ npm path added to ~/.bashrc.
```

---

### Script Step 3 — Working Directory

No input required. Creates `~/dev_projects`.

```
STEP 3: Working directory
✅ ~/dev_projects created.
```

---

### Script Step 4 — Git Setup

```
STEP 4: Git setup
Set up Git? (y/n): y
```

Enter `y`. The script will:

1. Install git if not already present
2. Ask for your name and email — use what is linked to your GitHub account
3. Generate an SSH key on the VM — this is separate from your Mac key; it is how the VM authenticates to GitHub
4. Display the VM's public key and pause

When the script displays the key and pauses:

```
============================================
  ACTION REQUIRED: Add this key to GitHub
============================================

ssh-rsa AAAA...your key here...

Go to: https://github.com/settings/keys
Click 'New SSH key', paste the key above, save.

Press Enter once you've added the key to GitHub...
```

**To add the key to GitHub:**
1. Go to [github.com](https://github.com)
2. Click your profile picture (top right) → **Settings**
3. In the left sidebar click **SSH and GPG keys**
4. Click **New SSH key**
5. Paste the key and save

Then come back to the terminal and press Enter. The script will test the connection and confirm.

---

### Script Step 5 — Claude Code CLI

```
STEP 5: Claude Code CLI
Install and configure Claude Code CLI? (y/n): y
```

Enter `y`. The script will:

1. Install Node.js
2. Configure a global npm directory at `~/.npm-global`
3. Install Claude Code via npm
4. Write `~/.claude/settings.json` — routes Claude Code through Concentrate and sets the default model
5. Run a quick test

```
✅ Claude Code working: setup confirmed
```

If the test is inconclusive, run `claude /status` after setup to verify manually.

---

### Script Completion

```
============================================
  Setup Complete
============================================

Summary:
  ~/.secrets        — API keys and model config
  ~/.bashrc         — sources ~/.secrets on login
  ~/dev_projects    — your working directory
```

---

## Part 5 — Verify Everything Works

```bash
source ~/.bashrc
```

**Environment variables loaded:**
```bash
printenv | grep -E '(ANTHROPIC|CONCENTRATE)'
```
You should see `ANTHROPIC_BASE_URL=https://api.concentrate.ai`. If you see `api.anthropic.com`, run `source ~/.bashrc` and try again.

**Claude Code routing through Concentrate:**
```bash
claude -p "say hello and tell me what model you are"
```

**Check active endpoint inside Claude Code:**
```bash
claude
/status
```
API endpoint should show `https://api.concentrate.ai`.

**Git identity:**
```bash
git config --global user.name
git config --global user.email
```

**GitHub SSH from the VM:**
```bash
ssh -T git@github.com
```
Expected: `Hi YOUR_USERNAME! You've successfully authenticated...`

---

## Part 6 — Clone Your Repo

```bash
cd ~/dev_projects
git clone git@github.com:YOUR_GITHUB_USERNAME/YOUR_REPO.git
cd YOUR_REPO
```

Create a `.gitignore` before any other work:

```bash
cat > .gitignore << 'EOF'
.secrets
.env
*.key
__pycache__/
node_modules/
.DS_Store
EOF
```

Commit it:

```bash
git add .gitignore && git commit -m "add .gitignore" && git push
```

> **Critical:** `.secrets` must be in your `.gitignore`. If you ever accidentally commit an API key, rotate it immediately — get a new key from the Concentrate dashboard and revoke the old one.

---

## Useful Commands

```bash
# One-shot Claude Code prompt
claude -p "your prompt here"

# Check all environment variables
printenv | grep -E '(ANTHROPIC|CONCENTRATE)'

# Check Claude Code config
cat ~/.claude/settings.json

# Check active model and endpoint inside Claude Code
claude
/status

# Switch models inside Claude Code
/model minimax-m2-7-highspeed
/model claude-opus-4-7
/model gpt-5.4

# Check Concentrate API health (no auth needed)
curl https://api.concentrate.ai/v1/responses/health

# List all available models (auth required)
curl https://api.concentrate.ai/v1/models \
  -H "Authorization: Bearer $CONCENTRATE_API_KEY"
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `claude /status` shows `api.anthropic.com` | Run `source ~/.bashrc` and try again |
| SSH to GitHub says Permission denied | VM's public key not added to GitHub — repeat the GitHub step in Part 4 |
| Claude Code returns auth error | Concentrate key may have no credits — contact your manager |
| SSH to VM asks for a password | Key not injected correctly — check for leading/trailing spaces, delete VM and reprovision |
| Script exits unexpectedly mid-run | Note which step — script is idempotent, safe to re-run from the top |
| All prompts skipped silently | You ran `curl | bash` directly — download first then run: see Part 4 |

---

## Next Steps

- **Mac IDE setup** (connect Zed to your VM over SSH) → `mac_ide_setup.md`
- **Concentrate API reference** → `Full_Concentrate_API.md`
- **Blue Lobster API reference** → `Full_Blue_Lobster_API.md`
