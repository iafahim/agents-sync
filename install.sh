#!/usr/bin/env bash
# =============================================================================
# AGENTS-SYNC Unix Installer
# =============================================================================
#
# Installs agents-sync as a Git alias and system command on Unix systems.
#
# Usage:
#   ./install.sh              Install with git alias
#   ./install.sh --skip-git   Install without git alias
#
# =============================================================================

set -euo pipefail

VERSION="1.0.0"
INSTALL_DIR="${HOME}/.agents-sync"
BIN_DIR="${INSTALL_DIR}/bin"
SCRIPT_PATH="${BIN_DIR}/agents-sync.sh"
SYMLINK_PATH="/usr/local/bin/agents-sync"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

# Logging
log_info() { echo -e "${CYAN}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Parse arguments
SKIP_GIT_ALIAS=0
for arg in "$@"; do
    case $arg in
        --skip-git) SKIP_GIT_ALIAS=1 ;;
        -h|--help)
            echo "Usage: $0 [--skip-git]"
            exit 0
            ;;
    esac
done

echo ""
echo "============================================================================"
echo "AGENTS-SYNC v${VERSION} - Unix Installer"
echo "============================================================================"
echo ""

# Create directories
log_info "Creating installation directories..."
mkdir -p "$BIN_DIR"

# Copy main script
log_info "Installing agents-sync.sh..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$SCRIPT_DIR/agents-sync.sh" ]]; then
    # Running via curl | bash, download from GitHub
    log_info "Downloading agents-sync.sh from GitHub..."
    curl -sSL "https://raw.githubusercontent.com/IAFahim/agents-sync/main/agents-sync.sh" -o "$SCRIPT_PATH"
else
    cp "$SCRIPT_DIR/agents-sync.sh" "$SCRIPT_PATH"
fi
chmod +x "$SCRIPT_PATH"

# Create symlink to /usr/local/bin
log_info "Creating symlink to /usr/local/bin..."
if [[ -w /usr/local/bin ]] || command -v sudo &> /dev/null; then
    if [[ -w /usr/local/bin ]]; then
        ln -sf "$SCRIPT_PATH" "$SYMLINK_PATH"
    else
        sudo ln -sf "$SCRIPT_PATH" "$SYMLINK_PATH"
    fi
    log_success "Symlink created: $SYMLINK_PATH"
else
    log_warn "Cannot create symlink in /usr/local/bin (requires sudo)"
    log_info "Add $BIN_DIR to your PATH manually"
fi

# Create git alias
if [[ $SKIP_GIT_ALIAS -eq 0 ]]; then
    log_info "Creating git alias..."

    # Check if git is installed
    if command -v git &> /dev/null; then
        # Check if alias already exists
        if git config --global alias.agents-sync &> /dev/null; then
            log_info "Git alias already exists"
        else
            # Create git alias
            git config --global alias.agents-sync "!bash $SCRIPT_PATH"
            log_success "Git alias created: git agents-sync"
        fi
    else
        log_warn "Git not found, skipping git alias"
    fi
else
    log_info "Skipping git alias"
fi

echo ""
echo "============================================================================"
echo "INSTALLATION COMPLETE"
echo "============================================================================"
echo ""
echo "Installation location:"
echo "  $BIN_DIR"
echo ""
echo "Usage:"
echo "  agents-sync init"
echo "  agents-sync local"
echo "  agents-sync global"
echo "  agents-sync edit"
echo "  agents-sync status"
echo ""
if [[ $SKIP_GIT_ALIAS -eq 0 ]] && command -v git &> /dev/null; then
    echo "Git alias:"
    echo "  git agents-sync init"
    echo "  git agents-sync local"
    echo ""
fi
echo "NOTE: Restart your terminal for changes to take effect"
echo ""
