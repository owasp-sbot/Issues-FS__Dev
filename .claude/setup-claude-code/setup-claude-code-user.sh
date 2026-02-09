#!/bin/bash
# =============================================================================
# setup-claude-code-user.sh
# Creates a sandboxed macOS user for running Claude Code with restricted access
# =============================================================================
# Usage: sudo ./setup-claude-code-user.sh
# =============================================================================

set -euo pipefail

# ---- Configuration (edit these) ---------------------------------------------
source "$(dirname "$0")/config.env"

# ---- Color output -----------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---- Pre-flight checks -----------------------------------------------------
[[ $EUID -ne 0 ]] && error "This script must be run as root (use sudo)"

# Check if user already exists
if dscl . -read "/Users/${CC_USERNAME}" &>/dev/null; then
    warn "User '${CC_USERNAME}' already exists. Skipping user creation."
    SKIP_USER_CREATE=true
else
    SKIP_USER_CREATE=false
fi

# ---- Step 1: Find an available UID -----------------------------------------
if [[ "$SKIP_USER_CREATE" == "false" ]]; then
    info "Finding available UID..."
    if [[ -z "$CC_UID" ]]; then
        CC_UID=550
        while dscl . -list /Users UniqueID | awk '{print $2}' | grep -q "^${CC_UID}$"; do
            CC_UID=$((CC_UID + 1))
        done
    fi
    ok "Will use UID: ${CC_UID}"
fi

# ---- Step 2: Create the user -----------------------------------------------
if [[ "$SKIP_USER_CREATE" == "false" ]]; then
    info "Creating user '${CC_USERNAME}'..."

    dscl . -create "/Users/${CC_USERNAME}"
    dscl . -create "/Users/${CC_USERNAME}" UserShell /bin/zsh
    dscl . -create "/Users/${CC_USERNAME}" RealName "${CC_REALNAME}"
    dscl . -create "/Users/${CC_USERNAME}" UniqueID "${CC_UID}"
    dscl . -create "/Users/${CC_USERNAME}" PrimaryGroupID 20  # staff
    dscl . -create "/Users/${CC_USERNAME}" NFSHomeDirectory "/Users/${CC_USERNAME}"

    # Set password (non-interactive)
    dscl . -passwd "/Users/${CC_USERNAME}" "${CC_PASSWORD}"

    # Hide from login screen
    dscl . -create "/Users/${CC_USERNAME}" IsHidden 1

    # Create home directory
    mkdir -p "/Users/${CC_USERNAME}"
    chown "${CC_USERNAME}:staff" "/Users/${CC_USERNAME}"
    chmod 750 "/Users/${CC_USERNAME}"

    ok "User '${CC_USERNAME}' created (UID: ${CC_UID}, hidden from login)"
fi

# ---- Step 3: Create restricted bin directory --------------------------------
info "Setting up restricted bin directory..."
RESTRICTED_BIN="/Users/${CC_USERNAME}/restricted-bin"
mkdir -p "$RESTRICTED_BIN"

# Remove old symlinks
find "$RESTRICTED_BIN" -type l -delete 2>/dev/null || true

# Read allowed executables from config and create symlinks
IFS=',' read -ra CMDS <<< "$CC_ALLOWED_EXECUTABLES"
for cmd in "${CMDS[@]}"; do
    cmd=$(echo "$cmd" | xargs)  # trim whitespace
    target=$(which "$cmd" 2>/dev/null || true)
    if [[ -n "$target" ]]; then
        ln -sf "$target" "${RESTRICTED_BIN}/${cmd}"
        ok "  Linked: ${cmd} -> ${target}"
    else
        warn "  Not found: ${cmd} (skipping)"
    fi
done

chown -R "${CC_USERNAME}:staff" "$RESTRICTED_BIN"
ok "Restricted bin ready at ${RESTRICTED_BIN}"

# ---- Step 4: Set up filesystem ACLs ----------------------------------------
info "Configuring filesystem ACLs..."

# Read/Write directories
IFS=',' read -ra RW_DIRS <<< "$CC_RW_DIRECTORIES"
for dir in "${RW_DIRS[@]}"; do
    dir=$(echo "$dir" | xargs)
    if [[ -d "$dir" ]]; then
        chmod -R +a "${CC_USERNAME} allow read,write,execute,delete,add_file,add_subdirectory,list,search,file_inherit,directory_inherit" "$dir"
        ok "  R/W ACL: ${dir}"
    else
        warn "  Directory not found (skipping R/W): ${dir}"
    fi
done

# Read-Only directories
IFS=',' read -ra RO_DIRS <<< "$CC_RO_DIRECTORIES"
for dir in "${RO_DIRS[@]}"; do
    dir=$(echo "$dir" | xargs)
    if [[ -d "$dir" ]]; then
        chmod -R +a "${CC_USERNAME} allow read,execute,list,search,file_inherit,directory_inherit" "$dir"
        ok "  R/O ACL: ${dir}"
    else
        warn "  Directory not found (skipping R/O): ${dir}"
    fi
done

ok "ACLs configured"

# ---- Step 5: Copy Claude Code config to new user's home --------------------
info "Setting up Claude Code configuration..."
CC_HOME="/Users/${CC_USERNAME}"
mkdir -p "${CC_HOME}/.claude"

# Copy the claude settings if a template exists
if [[ -f "$(dirname "$0")/claude-settings.json" ]]; then
    cp "$(dirname "$0")/claude-settings.json" "${CC_HOME}/.claude/settings.json"
    ok "Copied claude-settings.json"
fi

chown -R "${CC_USERNAME}:staff" "${CC_HOME}/.claude"
ok "Claude Code config directory ready"

# ---- Step 6: Verify setup --------------------------------------------------
info "Verifying setup..."

echo ""
echo "=============================================="
echo "  Sandbox User Setup Complete"
echo "=============================================="
echo ""
echo "  Username:        ${CC_USERNAME}"
echo "  UID:             $(dscl . -read /Users/${CC_USERNAME} UniqueID | awk '{print $2}')"
echo "  Home:            /Users/${CC_USERNAME}"
echo "  Restricted bin:  ${RESTRICTED_BIN}"
echo "  Hidden:          yes"
echo ""
echo "  R/W directories:"
IFS=',' read -ra RW_DIRS <<< "$CC_RW_DIRECTORIES"
for dir in "${RW_DIRS[@]}"; do echo "    - $(echo $dir | xargs)"; done
echo ""
echo "  R/O directories:"
IFS=',' read -ra RO_DIRS <<< "$CC_RO_DIRECTORIES"
for dir in "${RO_DIRS[@]}"; do echo "    - $(echo $dir | xargs)"; done
echo ""
echo "  Allowed executables:"
ls -1 "$RESTRICTED_BIN" | sed 's/^/    - /'
echo ""
echo "=============================================="
echo ""
echo "  To run Claude Code sandboxed:"
echo "    ./run-claude-code.sh"
echo ""
echo "  To verify permissions:"
echo "    ./verify-sandbox.sh"
echo ""
echo "  To remove the sandbox user:"
echo "    sudo ./teardown-claude-code-user.sh"
echo ""
echo "=============================================="
