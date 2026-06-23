#!/bin/bash
# =============================================================================
# Concentrate.ai / Blue Lobster — New VM Setup Script
# Run this once on a fresh Ubuntu 22.04 VM.
# Idempotent: safe to run more than once.
# =============================================================================

set -e

echo ""
echo "============================================"
echo "  Concentrate.ai VM Setup"
echo "============================================"
echo ""

# -----------------------------------------------------------------------------
# STEP 1: Concentrate API Key
# -----------------------------------------------------------------------------
echo "STEP 1: Concentrate API Key"
echo ""

if grep -q "CONCENTRATE_API_KEY" ~/.secrets 2>/dev/null; then
    echo "✅ ~/.secrets already contains CONCENTRATE_API_KEY — skipping."
else
    read -p "Enter your Concentrate API key (starts with sk-cn-): " CONCENTRATE_KEY
    echo ""

    if [[ ! "$CONCENTRATE_KEY" == sk-cn-* ]]; then
        echo "⚠️  Warning: key doesn't start with sk-cn- — double check this later."
    fi

    # Write ~/.secrets
    cat > ~/.secrets << EOF
export CONCENTRATE_API_KEY="${CONCENTRATE_KEY}"
export ANTHROPIC_API_KEY="\$CONCENTRATE_API_KEY"
export ANTHROPIC_BASE_URL="https://api.concentrate.ai"
export ANTHROPIC_MODEL="minimax-m2-7-highspeed"
export ANTHROPIC_DEFAULT_SONNET_MODEL="minimax-m2-7-highspeed"
export ANTHROPIC_DEFAULT_OPUS_MODEL="minimax-m2-7-highspeed"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="minimax-m2-7-highspeed"
EOF

    echo "✅ ~/.secrets written."
fi

# Load secrets into current session
source ~/.secrets

# -----------------------------------------------------------------------------
# STEP 2: Patch ~/.bashrc to source ~/.secrets and set npm path
# -----------------------------------------------------------------------------
echo ""
echo "STEP 2: Shell configuration"
echo ""

if grep -q "source ~/.secrets" ~/.bashrc; then
    echo "✅ ~/.bashrc already sources ~/.secrets — skipping."
else
    echo "" >> ~/.bashrc
    echo "# Concentrate.ai setup" >> ~/.bashrc
    echo "source ~/.secrets" >> ~/.bashrc
    echo "✅ ~/.bashrc updated to source ~/.secrets."
fi

if grep -q "npm-global" ~/.bashrc; then
    echo "✅ npm path already in ~/.bashrc — skipping."
else
    echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
    echo "✅ npm path added to ~/.bashrc."
fi

# -----------------------------------------------------------------------------
# STEP 3: Create dev_projects directory
# -----------------------------------------------------------------------------
echo ""
echo "STEP 3: Working directory"
echo ""

if [ -d ~/dev_projects ]; then
    echo "✅ ~/dev_projects already exists — skipping."
else
    mkdir -p ~/dev_projects
    echo "✅ ~/dev_projects created."
fi

# -----------------------------------------------------------------------------
# STEP 4: Git setup
# -----------------------------------------------------------------------------
echo ""
echo "STEP 4: Git setup"
echo ""

read -p "Set up Git? (y/n): " SETUP_GIT
echo ""

if [[ "$SETUP_GIT" == "y" || "$SETUP_GIT" == "Y" ]]; then

    # Install git if needed
    if ! command -v git &>/dev/null; then
        echo "Installing git..."
        sudo apt update -q && sudo apt install git -y -q
        echo "✅ git installed."
    else
        echo "✅ git already installed."
    fi

    # Git identity
    CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
    CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

    if [[ -n "$CURRENT_NAME" && -n "$CURRENT_EMAIL" ]]; then
        echo "✅ Git identity already set: $CURRENT_NAME <$CURRENT_EMAIL>"
        read -p "   Override? (y/n): " OVERRIDE_GIT
        if [[ "$OVERRIDE_GIT" == "y" || "$OVERRIDE_GIT" == "Y" ]]; then
            CURRENT_NAME=""
            CURRENT_EMAIL=""
        fi
    fi

    if [[ -z "$CURRENT_NAME" ]]; then
        read -p "Your name (for git commits): " GIT_NAME
        read -p "Your email (linked to your GitHub account): " GIT_EMAIL
        git config --global user.name "$GIT_NAME"
        git config --global user.email "$GIT_EMAIL"
        echo "✅ Git identity set."
    fi

    # SSH key for GitHub
    if [ -f ~/.ssh/id_rsa.pub ]; then
        echo "✅ SSH key already exists at ~/.ssh/id_rsa.pub — skipping key generation."
    else
        read -p "Email to embed in SSH key (can be same as git email): " SSH_EMAIL
        ssh-keygen -t rsa -b 4096 -C "$SSH_EMAIL" -f ~/.ssh/id_rsa -N ""
        echo "✅ SSH key generated."
    fi

    echo ""
    echo "============================================"
    echo "  ACTION REQUIRED: Add this key to GitHub"
    echo "============================================"
    echo ""
    cat ~/.ssh/id_rsa.pub
    echo ""
    echo "Go to: https://github.com/settings/keys"
    echo "Click 'New SSH key', paste the key above, save."
    echo ""
    read -p "Press Enter once you've added the key to GitHub..."

    # Test GitHub connection
    echo ""
    echo "Testing GitHub connection..."
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo "✅ GitHub SSH connection confirmed."
    else
        echo "⚠️  GitHub connection test inconclusive — verify manually with: ssh -T git@github.com"
    fi

    # Auto git pull on every terminal launch
    if ! grep -q "cd ~/dev_projects && git pull" ~/.bashrc; then
        echo '(cd ~/dev_projects && git pull --quiet 2>/dev/null) > /dev/null 2>&1 &' >> ~/.bashrc
        echo "✅ Auto git pull added to ~/.bashrc"
    fi

else
    echo "⏭️  Skipping git setup."
fi

# -----------------------------------------------------------------------------
# STEP 5: Claude Code CLI
# -----------------------------------------------------------------------------
echo ""
echo "STEP 5: Claude Code CLI"
echo ""

read -p "Install and configure Claude Code CLI? (y/n): " SETUP_CLAUDE
echo ""

if [[ "$SETUP_CLAUDE" == "y" || "$SETUP_CLAUDE" == "Y" ]]; then

    # Install Node.js if needed
    if ! command -v node &>/dev/null; then
        echo "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        sudo apt-get install -y nodejs -q
        echo "✅ Node.js installed."
    else
        echo "✅ Node.js already installed: $(node --version)"
    fi

    # Configure npm global directory
    if [ ! -d ~/.npm-global ]; then
        mkdir -p ~/.npm-global
        npm config set prefix '~/.npm-global'
        echo "✅ npm global directory configured."
    fi

    # Reload PATH for this session
    export PATH=~/.npm-global/bin:$PATH

    # Install Claude Code
    if command -v claude &>/dev/null; then
        echo "✅ Claude Code already installed: $(claude --version)"
    else
        echo "Installing Claude Code..."
        npm install -g @anthropic-ai/claude-code
        echo "✅ Claude Code installed."
    fi

    # Write ~/.claude/settings.json
    mkdir -p ~/.claude

    if [ -f ~/.claude/settings.json ]; then
        echo "✅ ~/.claude/settings.json already exists — skipping."
    else
        cat > ~/.claude/settings.json << 'EOF'
{
  "apiKeyHelper": "echo $CONCENTRATE_API_KEY",
  "theme": "dark",
  "model": "minimax-m2-7-highspeed"
}
EOF
        echo "✅ ~/.claude/settings.json written."
    fi

    # Verify
    echo ""
    echo "Testing Claude Code..."
    RESPONSE=$(claude -p "Reply with only the words: setup confirmed" 2>/dev/null || echo "")
    if [[ -n "$RESPONSE" ]]; then
        echo "✅ Claude Code working: $RESPONSE"
    else
        echo "⚠️  Claude Code test inconclusive. Run 'claude /status' to verify manually."
    fi

else
    echo "⏭️  Skipping Claude Code setup."
fi

# -----------------------------------------------------------------------------
# DONE
# -----------------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Setup Complete"
echo "============================================"
echo ""
echo "Summary:"
echo "  ~/.secrets        — API keys and model config"
echo "  ~/.bashrc         — sources ~/.secrets on login"
echo "  ~/dev_projects    — your working directory"
echo ""
echo "Next steps:"
echo "  • Clone your repo: cd ~/dev_projects && git clone <your-repo-ssh-url>"
echo "  • Reload shell:    source ~/.bashrc"
echo "  • Test Claude:     claude -p 'hello'"
echo ""
