#!/usr/bin/env bash

set -e

# ----------------------------
# FUNCTIONS (MISSING FIX)
# ----------------------------
log() {
  echo -e "$1"
}

run_cmd() {
  eval "$1"
}

# ----------------------------
# SUDO HANDLING
# ----------------------------
SUDO=""
if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
fi

# ----------------------------
# Validate bash
# ----------------------------
if [ -z "$BASH_VERSION" ]; then
  echo "❌ Please run with bash: ./install.sh"
  exit 1
fi

log "🚀 Starting Dev Environment Setup..."

# ----------------------------
# Detect OS
# ----------------------------
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
  OS="mac"
elif grep -qi microsoft /proc/version 2>/dev/null; then
  OS="wsl"
else
  OS="linux"
fi

log "👉 Detected OS: $OS"

# ----------------------------
# Ensure /usr/local/bin exists
# ----------------------------
run_cmd "$SUDO mkdir -p /usr/local/bin"

# ----------------------------
# Pre-flight checks
# ----------------------------
log "🔍 Running pre-flight checks..."

command -v curl >/dev/null 2>&1 || log "⚠️ curl not found"
command -v jq >/dev/null 2>&1 || log "⚠️ jq not found"
command -v aws >/dev/null 2>&1 || log "⚠️ aws cli not found"

# ----------------------------
# Install dependencies
# ----------------------------
install_mac() {
  log "🍺 Installing dependencies (Mac)..."

  if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew not found. Install from https://brew.sh"
    exit 1
  fi

  brew update

  brew list awscli >/dev/null 2>&1 || brew install awscli
  brew list jq >/dev/null 2>&1 || brew install jq

  if ! command -v session-manager-plugin >/dev/null 2>&1; then
    brew install --cask session-manager-plugin
  fi
}

install_linux() {
  log "🐧 Installing dependencies (Linux/WSL)..."

  run_cmd "$SUDO apt update -y"
  run_cmd "$SUDO apt install -y unzip curl jq"

  if ! command -v aws >/dev/null 2>&1; then
    log "⬇️ Installing AWS CLI..."
    run_cmd "curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip"
    run_cmd "unzip -q awscliv2.zip"
    run_cmd "$SUDO ./aws/install"
    run_cmd "rm -rf aws awscliv2.zip"
  fi

  if ! command -v session-manager-plugin >/dev/null 2>&1; then
    log "⬇️ Installing Session Manager Plugin..."
    run_cmd "curl -s https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb -o ssm.deb"
    run_cmd "$SUDO dpkg -i ssm.deb"
    run_cmd "rm -f ssm.deb"
  fi
}

if [[ "$OS" == "mac" ]]; then
  install_mac
else
  install_linux
fi

# ----------------------------
# Install scripts
# ----------------------------
log "📦 Installing custom scripts..."

install_script() {
  SRC=$1
  DEST="/usr/local/bin/$(basename "$SRC")"

  if [ -f "$SRC" ]; then
    run_cmd "$SUDO cp $SRC $DEST"
    run_cmd "$SUDO chmod +x $DEST"
    log "✅ Installed $(basename "$SRC")"
  else
    log "⚠️ Missing script: $SRC"
  fi
}

install_script "scripts/aws-login"
install_script "scripts/db-pc"
install_script "scripts/find-win"
install_script "scripts/linux"
install_script "scripts/rds"
install_script "scripts/win"
install_script "scripts/win-pc"

# ----------------------------
# Setup rds-map
# ----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log "📝 Updating ~/.rds-map..."
run_cmd "cp $SCRIPT_DIR/templates/rds-map $HOME/.rds-map"
log "📝 Updating ~/.win-map..."
run_cmd "cp $SCRIPT_DIR/templates/win-map $HOME/.win-map"

# ----------------------------
# Detect shell
# ----------------------------
SHELL_NAME=$(basename "$SHELL")

if [[ "$SHELL_NAME" == "zsh" ]]; then
  SHELL_FILE="$HOME/.zshrc"
else
  SHELL_FILE="$HOME/.bashrc"
fi

log "⚙️ Updating $SHELL_FILE"

# Backup
cp "$SHELL_FILE" "$SHELL_FILE.bak.$(date +%s)"

append_if_not_exists() {
  LINE=$1
  FILE=$2

  if grep -Fxq "$LINE" "$FILE" 2>/dev/null; then
    echo "ℹ️ Already exists: $LINE"
  else
    echo "$LINE" >> "$FILE"
  fi
}

# Aliases

append_if_not_exists 'alias uat="linux uat"' "$SHELL_FILE"
append_if_not_exists 'alias prod="linux prod"' "$SHELL_FILE"
append_if_not_exists 'alias dbuat="rds uat"' "$SHELL_FILE"
append_if_not_exists 'alias dbprod="rds prod"' "$SHELL_FILE"
append_if_not_exists 'alias wuat="win uat"' "$SHELL_FILE"
append_if_not_exists 'alias wprod="win prod"' "$SHELL_FILE"


# PATH FIX (IMPORTANT)
if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
  append_if_not_exists 'export PATH="/usr/local/bin:$PATH"' "$SHELL_FILE"
fi

# ----------------------------
# Done
# ----------------------------
log ""
log "🎉 Setup Complete!"
log ""
log "👉 Reload shell:"
log "   source $SHELL_FILE"
log ""
log "👉 Usage:"
log "   uat - for connecting linux uat servers"
log "   prod - for connecting linux prod servers"
log "   wuat - for connecting windows uat servers"
log "   wprod - for connecting windows prod servers"
log "   dbuat - open tunnels for uat dbs"
log "   dbprod - open tunnels for prod dbs"
log "   db-pc - Checking ports actively listening or not"
log ""