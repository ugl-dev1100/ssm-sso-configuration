# #!/usr/bin/env bash

# set -e

# # ----------------------------
# # FUNCTIONS (MISSING FIX)
# # ----------------------------
# log() {
#   echo -e "$1"
# }

# run_cmd() {
#   eval "$1"
# }

# # ----------------------------
# # SUDO HANDLING
# # ----------------------------
# SUDO=""
# if [ "$EUID" -ne 0 ]; then
#   SUDO="sudo"
# fi

# # ----------------------------
# # Validate bash
# # ----------------------------
# if [ -z "$BASH_VERSION" ]; then
#   echo "❌ Please run with bash: ./install.sh"
#   exit 1
# fi

# log "🚀 Starting Dev Environment Setup..."

# # ----------------------------
# # Detect OS
# # ----------------------------
# OS="unknown"
# if [[ "$OSTYPE" == "darwin"* ]]; then
#   OS="mac"
# elif grep -qi microsoft /proc/version 2>/dev/null; then
#   OS="wsl"
# else
#   OS="linux"
# fi

# log "👉 Detected OS: $OS"

# # ----------------------------
# # Ensure /usr/local/bin exists
# # ----------------------------
# run_cmd "$SUDO mkdir -p /usr/local/bin"

# # ----------------------------
# # Pre-flight checks
# # ----------------------------
# log "🔍 Running pre-flight checks..."

# command -v curl >/dev/null 2>&1 || log "⚠️ curl not found"
# command -v jq >/dev/null 2>&1 || log "⚠️ jq not found"
# command -v aws >/dev/null 2>&1 || log "⚠️ aws cli not found" 

# # ----------------------------
# # Install dependencies
# # ----------------------------
# install_mac() {
#   log "🍺 Installing dependencies (Mac)..."

#   if ! command -v brew >/dev/null 2>&1; then
#     echo "❌ Homebrew not found. Install from https://brew.sh"
#     exit 1
#   fi

#   brew update

#   brew list awscli >/dev/null 2>&1 || brew install awscli
#   brew list jq >/dev/null 2>&1 || brew install jq

#   if ! command -v session-manager-plugin >/dev/null 2>&1; then
#     brew install --cask session-manager-plugin
#   fi
# }

# install_linux() {
#   log "🐧 Installing dependencies (Linux/WSL)..."

#   run_cmd "$SUDO apt update -y"
#   run_cmd "$SUDO apt install -y unzip curl jq wslu"

#   if ! command -v aws >/dev/null 2>&1; then
#     log "⬇️ Installing AWS CLI..."
#     run_cmd "curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip"
#     run_cmd "unzip -q awscliv2.zip"
#     run_cmd "$SUDO ./aws/install"
#     run_cmd "rm -rf aws awscliv2.zip"
#   fi

#   if ! command -v session-manager-plugin >/dev/null 2>&1; then
#     log "⬇️ Installing Session Manager Plugin..."
#     run_cmd "curl -s https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb -o ssm.deb"
#     run_cmd "$SUDO dpkg -i ssm.deb"
#     run_cmd "rm -f ssm.deb"
#   fi
# }

# if [[ "$OS" == "mac" ]]; then
#   install_mac
# else
#   install_linux
# fi

# # ----------------------------
# # Install scripts
# # ----------------------------
# log "📦 Installing custom scripts..."

# install_script() {
#   SRC=$1
#   DEST="/usr/local/bin/$(basename "$SRC")"

#   if [ -f "$SRC" ]; then
#     run_cmd "$SUDO cp $SRC $DEST"
#     run_cmd "$SUDO chmod +x $DEST"
#     log "✅ Installed $(basename "$SRC")"
#   else
#     log "⚠️ Missing script: $SRC"
#   fi
# }

# install_script "scripts/aws-login"
# install_script "scripts/dbpc"
# install_script "scripts/linux"
# install_script "scripts/rds"


# # ----------------------------
# # Setup rds-map
# # ----------------------------

# RDS_MAP_SRC="$SCRIPT_DIR/templates/rds-map"
# RDS_MAP_DEST="$HOME/.rds-map"

# if [ ! -f "$RDS_MAP_SRC" ]; then
#   log "❌ Expected template not found: $RDS_MAP_SRC"
#   exit 1
# fi

# if [ ! -f "$RDS_MAP_DEST" ]; then
#   cp "$RDS_MAP_SRC" "$RDS_MAP_DEST"
#   log "✅ Created ~/.rds-map"
#   log "👉 Please update ~/.rds-map with your DB details"
# else
#   log "ℹ️ ~/.rds-map already exists (skipping)"
# fi

# # ----------------------------
# # Detect shell
# # ----------------------------
# SHELL_NAME=$(basename "$SHELL")

# if [[ "$SHELL_NAME" == "zsh" ]]; then
#   SHELL_FILE="$HOME/.zshrc"
# else
#   SHELL_FILE="$HOME/.bashrc"
# fi

# log "⚙️ Updating $SHELL_FILE"

# # Backup
# cp "$SHELL_FILE" "$SHELL_FILE.bak.$(date +%s)"


# append_block() {
#   NAME="$1"
#   FILE="$2"
#   CONTENT="$3"

#   # Remove old block if exists
#   sed -i.bak "/# >>> $NAME >>>/,/# <<< $NAME <<</d" "$FILE"

#   # Add fresh block
#   {
#     echo ""
#     echo "# >>> $NAME >>>"
#     echo "$CONTENT"
#     echo "# <<< $NAME <<<"
#   } >> "$FILE"
# }

# # Aliases

# append_block "ALIASES" "$SHELL_FILE" '
# alias uat="linux uat"
# alias prod="linux prod"
# alias dbuat="rds uat"
# alias dbprod="rds prod"
# '

# append_block "AWS_AUTO_LOGIN" "$SHELL_FILE" '

# aws_auto_login() {
#   aws sts get-caller-identity --profile uat >/dev/null 2>&1 || aws-login uat
#   aws sts get-caller-identity --profile prod >/dev/null 2>&1 || aws-login prod
# }

# aws_auto_login
# '

# # WSL specific config
# if [[ "$OS" == "wsl" ]]; then
#   append_block "WSL_CONFIG" "$SHELL_FILE" '
# export BROWSER=wslview
# '
# fi

# # PATH FIX (IMPORTANT)
# if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
#   append_if_not_exists 'export PATH="/usr/local/bin:$PATH"' "$SHELL_FILE"
# fi
# # ----------------------------
# # Done
# # ----------------------------
# log ""
# log "🎉 Setup Complete!"
# log ""
# log "👉 Reload shell:"
# log "   source $SHELL_FILE"
# log ""
# log "👉 Usage:"
# log "   uat - for connecting linux uat servers"
# log "   prod - for connecting linux prod servers"
# log "   dbuat - open tunnels for uat dbs"
# log "   dbprod - open tunnels for prod dbs"
# log "   dbpc - Checking ports actively listening or not"
# log ""

#!/usr/bin/env bash

set -e

# ----------------------------
# SCRIPT DIR (FIXED)
# ----------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----------------------------
# FUNCTIONS
# ----------------------------
log() {
  echo -e "$1"
}

run_cmd() {
  eval "$1"
}

append_if_not_exists() {
  local LINE="$1"
  local FILE="$2"

  grep -qxF "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
}

# Mac vs Linux sed compatibility
sed_inplace() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
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
  local SRC="$SCRIPT_DIR/$1"
  local DEST="/usr/local/bin/$(basename "$1")"

  if [ -f "$SRC" ]; then
    run_cmd "$SUDO cp \"$SRC\" \"$DEST\""
    run_cmd "$SUDO chmod +x \"$DEST\""
    log "✅ Installed $(basename "$1")"
  else
    log "⚠️ Missing script: $SRC"
  fi
}

install_script "scripts/aws-login"
install_script "scripts/dbpc"
install_script "scripts/linux"
install_script "scripts/rds"

# ----------------------------
# Setup rds-map
# ----------------------------
RDS_MAP_SRC="$SCRIPT_DIR/templates/rds-map"
RDS_MAP_DEST="$HOME/.rds-map"

if [ ! -f "$RDS_MAP_SRC" ]; then
  log "❌ Expected template not found: $RDS_MAP_SRC"
  log "👉 Script dir: $SCRIPT_DIR"
  log "👉 Current dir: $(pwd)"
  exit 1
fi

if [ ! -f "$RDS_MAP_DEST" ]; then
  cp "$RDS_MAP_SRC" "$RDS_MAP_DEST"
  log "✅ Created ~/.rds-map"
  log "👉 Please update ~/.rds-map with your DB details"
else
  log "ℹ️ ~/.rds-map already exists (skipping)"
fi

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

touch "$SHELL_FILE"
cp "$SHELL_FILE" "$SHELL_FILE.bak.$(date +%s)"

append_block() {
  local NAME="$1"
  local FILE="$2"
  local CONTENT="$3"

  sed_inplace "/# >>> $NAME >>>/,/# <<< $NAME <<</d" "$FILE"

  {
    echo ""
    echo "# >>> $NAME >>>"
    echo "$CONTENT"
    echo "# <<< $NAME <<<"
  } >> "$FILE"
}

# ----------------------------
# Aliases
# ----------------------------
append_block "ALIASES" "$SHELL_FILE" '
alias uat="linux uat"
alias prod="linux prod"
alias dbuat="rds uat"
alias dbprod="rds prod"
'

# ----------------------------
# AWS AUTO LOGIN
# ----------------------------
append_block "AWS_AUTO_LOGIN" "$SHELL_FILE" '
aws_auto_login() {
  aws sts get-caller-identity --profile uat >/dev/null 2>&1 || aws-login uat
  aws sts get-caller-identity --profile prod >/dev/null 2>&1 || aws-login prod
}
aws_auto_login
'

# ----------------------------
# WSL CONFIG
# ----------------------------
if [[ "$OS" == "wsl" ]]; then
  append_block "WSL_CONFIG" "$SHELL_FILE" '
export BROWSER=wslview
'
fi

# ----------------------------
# PATH FIX
# ----------------------------
append_if_not_exists 'export PATH="/usr/local/bin:$PATH"' "$SHELL_FILE"

# ----------------------------
# DONE
# ----------------------------
log ""
log "🎉 Setup Complete!"
log ""
log "👉 Reload shell:"
log "   source $SHELL_FILE"
log ""
log "👉 Usage:"
log "   uat     - connect to uat servers"
log "   prod    - connect to prod servers"
log "   dbuat   - open DB tunnel (uat)"
log "   dbprod  - open DB tunnel (prod)"
log "   dbpc    - check active ports"
log ""