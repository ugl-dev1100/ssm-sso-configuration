#!/usr/bin/env bash

set -e

# ----------------------------
# FLAGS
# ----------------------------
DRY_RUN=false
DEBUG=false

for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --debug)
      DEBUG=true
      set -x
      shift
      ;;
  esac
done

log() {
  echo -e "$1"
}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] $1"
  else
    eval "$1"
  fi
}

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

if [[ "$OS" == "unknown" ]]; then
  echo "❌ Unsupported OS"
  exit 1
fi

# ----------------------------
# Ensure /usr/local/bin exists
# ----------------------------
run_cmd "sudo mkdir -p /usr/local/bin"

# ----------------------------
# Pre-flight checks
# ----------------------------
log "🔍 Running pre-flight checks..."

command -v curl >/dev/null 2>&1 || log "⚠️ curl not found (will install)"
command -v jq >/dev/null 2>&1 || log "⚠️ jq not found (will install)"
command -v aws >/dev/null 2>&1 || log "⚠️ aws cli not found (will install)"

# ----------------------------
# Install dependencies
# ----------------------------
install_mac() {
  log "🍺 Installing dependencies (Mac)..."

  if ! command -v brew >/dev/null 2>&1; then
    echo "❌ Homebrew not found. Install from https://brew.sh"
    exit 1
  fi

  run_cmd "brew update"

  brew list awscli >/dev/null 2>&1 || run_cmd "brew install awscli"
  brew list jq >/dev/null 2>&1 || run_cmd "brew install jq"

  if ! command -v session-manager-plugin >/dev/null 2>&1; then
    run_cmd "brew install --cask session-manager-plugin"
  fi
}

install_linux() {
  log "🐧 Installing dependencies (Linux/WSL)..."

  run_cmd "apt update -y"
  run_cmd "apt install -y unzip curl jq"

  if ! command -v aws >/dev/null 2>&1; then
    log "⬇️ Installing AWS CLI..."
    run_cmd "curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip"
    run_cmd "unzip -q awscliv2.zip"
    run_cmd "sudo ./aws/install"
    run_cmd "rm -rf aws awscliv2.zip"
  fi

  if ! command -v session-manager-plugin >/dev/null 2>&1; then
    log "⬇️ Installing Session Manager Plugin..."
    run_cmd "curl -s https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb -o ssm.deb"
    run_cmd "sudo dpkg -i ssm.deb"
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
    run_cmd "cp $SRC $DEST"
    run_cmd "chmod +x $DEST"
    log "✅ Installed $(basename "$SRC")"
  else
    log "⚠️ Missing script: $SRC"
  fi
}

install_script "scripts/aws-login"
install_script "scripts/rds-instances"
install_script "scripts/instances"

# ----------------------------
# Setup rds-map
# ----------------------------
if [ ! -f "$HOME/.rds-map" ]; then
  log "📝 Creating ~/.rds-map..."
  run_cmd "cp templates/rds-map $HOME/.rds-map"
else
  log "✅ ~/.rds-map already exists"
fi

# ----------------------------
# Detect shell
# ----------------------------
SHELL_NAME=$(basename "$SHELL")

if [[ "$SHELL_NAME" == "zsh" ]]; then
  SHELL_FILE="$HOME/.zshrc"
elif [[ "$SHELL_NAME" == "bash" ]]; then
  SHELL_FILE="$HOME/.bashrc"
else
  log "⚠️ Unknown shell, defaulting to bashrc"
  SHELL_FILE="$HOME/.bashrc"
fi

log "⚙️ Updating $SHELL_FILE"

append_if_not_exists() {
  LINE=$1
  FILE=$2

  if grep -Fxq "$LINE" "$FILE" 2>/dev/null; then
    echo "ℹ️ Already exists: $LINE"
  else
    run_cmd "echo '$LINE' >> $FILE"
  fi
}

append_if_not_exists "aws-login uat" "$SHELL_FILE"
append_if_not_exists "aws-login prod" "$SHELL_FILE"

append_if_not_exists 'alias uat="instances uat"' "$SHELL_FILE"
append_if_not_exists 'alias prod="instances prod"' "$SHELL_FILE"

if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
  append_if_not_exists 'export PATH="/usr/local/bin:$PATH"' "$SHELL_FILE"
fi

# ----------------------------
# Done
# ----------------------------
log ""
log "🎉 Setup Complete!"
log ""
log "👉 Run:"
log "   aws sso login --profile uat"
log ""
log "👉 Usage:"
log "   uat"
log "   prod"
log "   rds-instances uat"
log ""
log "👉 Reload shell:"
log "   source $SHELL_FILE"
log ""