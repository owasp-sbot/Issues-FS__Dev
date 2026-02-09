#!/bin/bash
# =============================================================================
# teardown-claude-code-user.sh
# Removes the sandboxed Claude Code user and cleans up ACLs
# =============================================================================
# Usage: sudo ./teardown-claude-code-user.sh [--keep-acls]
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/config.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[[ $EUID -ne 0 ]] && error "This script must be run as root (use sudo)"

KEEP_ACLS=false
[[ "${1:-}" == "--keep-acls" ]] && KEEP_ACLS=true

# Verify user exists
if ! dscl . -read "/Users/${CC_USERNAME}" &>/dev/null; then
    warn "User '${CC_USERNAME}' does not exist. Nothing to do."
    exit 0
fi

echo ""
echo -e "${YELLOW}WARNING: This will permanently delete:${NC}"
echo "  - User account: ${CC_USERNAME}"
echo "  - Home directory: /Users/${CC_USERNAME}"
if [[ "$KEEP_ACLS" == "false" ]]; then
    echo "  - All ACLs for ${CC_USERNAME} on configured directories"
fi
echo ""
read -p "Are you sure? (type 'yes' to confirm): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { echo "Aborted."; exit 0; }

# ---- Step 1: Kill any running processes -------------------------------------
info "Killing any processes owned by '${CC_USERNAME}'..."
pkill -u "${CC_USERNAME}" 2>/dev/null || true
sleep 1
ok "Processes terminated"

# ---- Step 2: Remove ACLs ---------------------------------------------------
if [[ "$KEEP_ACLS" == "false" ]]; then
    info "Removing ACLs..."

    remove_acls_for_user() {
        local dir="$1"
        [[ ! -d "$dir" ]] && return

        # List ACLs, find entries for our user, remove them by index (in reverse order)
        local indices
        indices=$(ls -led "$dir" 2>/dev/null | grep -n "${CC_USERNAME}" | cut -d: -f1 | sort -rn)
        for idx in $indices; do
            chmod -a# $((idx - 1)) "$dir" 2>/dev/null || true
        done
    }

    IFS=',' read -ra RW_DIRS <<< "$CC_RW_DIRECTORIES"
    for dir in "${RW_DIRS[@]}"; do
        dir=$(echo "$dir" | xargs)
        remove_acls_for_user "$dir"
        ok "  Removed ACLs from: $dir"
    done

    IFS=',' read -ra RO_DIRS <<< "$CC_RO_DIRECTORIES"
    for dir in "${RO_DIRS[@]}"; do
        dir=$(echo "$dir" | xargs)
        remove_acls_for_user "$dir"
        ok "  Removed ACLs from: $dir"
    done
else
    warn "Keeping ACLs (--keep-acls specified)"
fi

# ---- Step 3: Delete home directory ------------------------------------------
info "Removing home directory..."
rm -rf "/Users/${CC_USERNAME}"
ok "Home directory removed"

# ---- Step 4: Delete user account --------------------------------------------
info "Deleting user account..."
dscl . -delete "/Users/${CC_USERNAME}"
ok "User '${CC_USERNAME}' deleted"

echo ""
echo "=============================================="
echo "  Teardown Complete"
echo "=============================================="
echo "  User '${CC_USERNAME}' has been removed."
echo "=============================================="
