#!/bin/bash
# =============================================================================
# run-claude-code.sh
# Launches Claude Code as the sandboxed user with restricted PATH
# =============================================================================
# Usage: ./run-claude-code.sh [optional claude args...]
# Example: ./run-claude-code.sh --project /Users/diniscruz/_dev/owasp-sbot/Issues-FS__Dev
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/config.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Verify user exists
if ! dscl . -read "/Users/${CC_USERNAME}" &>/dev/null; then
    error "User '${CC_USERNAME}' does not exist. Run setup-claude-code-user.sh first."
fi

# Locate claude binary
if [[ -n "${CC_CLAUDE_BIN}" ]]; then
    CLAUDE_BIN="${CC_CLAUDE_BIN}"
elif which claude &>/dev/null; then
    CLAUDE_BIN="$(which claude)"
else
    error "Cannot find 'claude' binary. Set CC_CLAUDE_BIN in config.env."
fi
info "Using claude binary: ${CLAUDE_BIN}"

# Build restricted PATH
RESTRICTED_BIN="/Users/${CC_USERNAME}/restricted-bin"
RESTRICTED_PATH="${RESTRICTED_BIN}:/usr/bin:/bin"

# Add Node.js directory if specified
if [[ -n "${CC_NODE_DIR}" ]]; then
    RESTRICTED_PATH="${CC_NODE_DIR}:${RESTRICTED_PATH}"
fi

# Add directory containing claude binary itself
CLAUDE_DIR="$(dirname "$CLAUDE_BIN")"
RESTRICTED_PATH="${CLAUDE_DIR}:${RESTRICTED_PATH}"

info "Restricted PATH: ${RESTRICTED_PATH}"

# Determine working directory
WORK_DIR="${1:-.}"
if [[ "$1" == "--project" ]] || [[ "$1" == "-p" ]]; then
    WORK_DIR="${2:-.}"
    shift 2
fi

info "Starting Claude Code as '${CC_USERNAME}'..."
echo ""

# Run Claude Code as the sandboxed user
sudo -u "${CC_USERNAME}" \
    env PATH="${RESTRICTED_PATH}" \
        HOME="/Users/${CC_USERNAME}" \
        TERM="${TERM}" \
        LANG="${LANG:-en_US.UTF-8}" \
    "${CLAUDE_BIN}" "$@"
