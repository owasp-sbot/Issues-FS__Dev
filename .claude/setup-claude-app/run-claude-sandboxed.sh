#!/bin/bash
# =============================================================================
# run-claude-sandboxed.sh
# Launches Claude.app inside a macOS sandbox profile that restricts filesystem
# access to only the configured project directories.
# =============================================================================
# Usage:
#   ./run-claude-sandboxed.sh                # launch with sandbox
#   ./run-claude-sandboxed.sh --dry-run      # print the command without running
#   ./run-claude-sandboxed.sh --test         # test sandbox restrictions
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/config.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---- Locate Claude.app -----------------------------------------------------
CLAUDE_APP="${CC_CLAUDE_APP:-/Applications/Claude.app}"
CLAUDE_BIN="${CLAUDE_APP}/Contents/MacOS/Claude"

if [[ ! -x "$CLAUDE_BIN" ]]; then
    error "Claude.app not found at ${CLAUDE_APP}. Set CC_CLAUDE_APP in config.env."
fi

# ---- Locate sandbox profile -------------------------------------------------
SANDBOX_PROFILE="${SCRIPT_DIR}/claude-sandbox.sb"

if [[ ! -f "$SANDBOX_PROFILE" ]]; then
    error "Sandbox profile not found at ${SANDBOX_PROFILE}"
fi

# ---- Mode handling ----------------------------------------------------------
MODE="${1:-run}"

case "$MODE" in
    --dry-run)
        info "Dry run — would execute:"
        echo ""
        echo "  sandbox-exec -f ${SANDBOX_PROFILE} \\"
        echo "    -D HOME=${HOME} \\"
        echo "    ${CLAUDE_BIN}"
        echo ""
        exit 0
        ;;
    --test)
        info "Testing sandbox restrictions..."
        echo ""

        # Test: can we read the project dir?
        info "Reading project directory..."
        if sandbox-exec -f "$SANDBOX_PROFILE" -D "HOME=${HOME}" \
            /bin/ls "${CC_RW_DIRECTORIES%%,*}" &>/dev/null; then
            ok "Can read project directory"
        else
            echo -e "  ${RED}✗ FAIL${NC}  Cannot read project directory"
        fi

        # Test: can we read Desktop? (should fail)
        info "Attempting to read ~/Desktop (should fail)..."
        if sandbox-exec -f "$SANDBOX_PROFILE" -D "HOME=${HOME}" \
            /bin/ls "${HOME}/Desktop" &>/dev/null; then
            echo -e "  ${RED}✗ FAIL${NC}  CAN read ~/Desktop (sandbox not working!)"
        else
            ok "Cannot read ~/Desktop (sandbox is working)"
        fi

        # Test: can we read .ssh? (should fail)
        info "Attempting to read ~/.ssh (should fail)..."
        if sandbox-exec -f "$SANDBOX_PROFILE" -D "HOME=${HOME}" \
            /bin/ls "${HOME}/.ssh" &>/dev/null; then
            echo -e "  ${RED}✗ FAIL${NC}  CAN read ~/.ssh (sandbox not working!)"
        else
            ok "Cannot read ~/.ssh (sandbox is working)"
        fi

        # Test: can we write to project dir?
        info "Writing to project directory..."
        TESTFILE="${CC_RW_DIRECTORIES%%,*}/.sandbox-test-$$"
        if sandbox-exec -f "$SANDBOX_PROFILE" -D "HOME=${HOME}" \
            /usr/bin/touch "$TESTFILE" 2>/dev/null; then
            rm -f "$TESTFILE"
            ok "Can write to project directory"
        else
            echo -e "  ${RED}✗ FAIL${NC}  Cannot write to project directory"
        fi

        # Test: can we write to Desktop? (should fail)
        info "Attempting to write to ~/Desktop (should fail)..."
        if sandbox-exec -f "$SANDBOX_PROFILE" -D "HOME=${HOME}" \
            /usr/bin/touch "${HOME}/Desktop/.sandbox-test-$$" 2>/dev/null; then
            rm -f "${HOME}/Desktop/.sandbox-test-$$"
            echo -e "  ${RED}✗ FAIL${NC}  CAN write to ~/Desktop (sandbox not working!)"
        else
            ok "Cannot write to ~/Desktop (sandbox is working)"
        fi

        echo ""
        info "Done. If all tests passed, the sandbox profile is working correctly."
        exit 0
        ;;
    run|"")
        # Continue to launch
        ;;
    *)
        echo "Usage: $0 [--dry-run | --test]"
        exit 1
        ;;
esac

# ---- Launch Claude.app inside sandbox ---------------------------------------
info "Launching Claude.app with sandbox restrictions..."
info "Profile: ${SANDBOX_PROFILE}"
info "R/W dirs: ${CC_RW_DIRECTORIES}"
info "R/O dirs: ${CC_RO_DIRECTORIES}"
echo ""

warn "The sandbox restricts Claude.app's filesystem access."
warn "If Claude.app behaves unexpectedly, check the sandbox profile."
echo ""

sandbox-exec -f "$SANDBOX_PROFILE" \
    -D "HOME=${HOME}" \
    "$CLAUDE_BIN" &

CLAUDE_PID=$!
ok "Claude.app launched (PID: ${CLAUDE_PID})"
echo ""
echo "To stop: kill ${CLAUDE_PID}"
echo "Or just quit Claude.app normally."
