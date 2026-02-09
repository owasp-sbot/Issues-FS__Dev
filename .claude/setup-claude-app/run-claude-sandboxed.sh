#!/bin/bash
# =============================================================================
# run-claude-sandboxed.sh
# Launches Claude.app inside a macOS sandbox profile that restricts filesystem
# access by denying sensitive paths.
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

PASS=0
FAIL=0

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; PASS=$((PASS + 1)); }
fail()  { echo -e "${RED}[FAIL]${NC}  $1"; FAIL=$((FAIL + 1)); }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }

# Helper: run a command inside the sandbox, capturing exit code
sandbox_run() {
    sandbox-exec -f "$SANDBOX_PROFILE" -D "HOME=${HOME}" "$@" 2>/dev/null
}

# ---- Locate Claude.app -----------------------------------------------------
CLAUDE_APP="${CC_CLAUDE_APP:-/Applications/Claude.app}"
CLAUDE_BIN="${CLAUDE_APP}/Contents/MacOS/Claude"

if [[ ! -x "$CLAUDE_BIN" ]]; then
    echo -e "${RED}[ERROR]${NC} Claude.app not found at ${CLAUDE_APP}. Set CC_CLAUDE_APP in config.env."
    exit 1
fi

# ---- Locate sandbox profile -------------------------------------------------
SANDBOX_PROFILE="${SCRIPT_DIR}/claude-sandbox.sb"

if [[ ! -f "$SANDBOX_PROFILE" ]]; then
    echo -e "${RED}[ERROR]${NC} Sandbox profile not found at ${SANDBOX_PROFILE}"
    exit 1
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
        info "Profile: ${SANDBOX_PROFILE}"
        info "HOME: ${HOME}"
        echo ""

        # ---- Tests that SHOULD SUCCEED (allowed paths) ----
        info "=== Allowed Access (should succeed) ==="
        echo ""

        PROJECT_DIR="${CC_RW_DIRECTORIES%%,*}"

        # Read project dir
        if sandbox_run /bin/ls "$PROJECT_DIR" >/dev/null; then
            ok "Can read project dir: ${PROJECT_DIR}"
        else
            fail "Cannot read project dir: ${PROJECT_DIR}"
        fi

        # Write to project dir
        TESTFILE="${PROJECT_DIR}/.sandbox-write-test-$$"
        if sandbox_run /usr/bin/touch "$TESTFILE" && rm -f "$TESTFILE"; then
            ok "Can write to project dir"
        else
            rm -f "$TESTFILE" 2>/dev/null
            fail "Cannot write to project dir"
        fi

        # Read system paths
        if sandbox_run /bin/ls /usr/bin >/dev/null; then
            ok "Can read /usr/bin"
        else
            fail "Cannot read /usr/bin"
        fi

        # Execute basic commands
        if sandbox_run /bin/echo "test" >/dev/null; then
            ok "Can execute /bin/echo"
        else
            fail "Cannot execute /bin/echo"
        fi

        # Git in project
        if sandbox_run /usr/bin/git -C "$PROJECT_DIR" status >/dev/null 2>&1; then
            ok "Can run git status in project"
        else
            # git might not be at /usr/bin/git
            GIT_PATH=$(which git 2>/dev/null || echo "/usr/bin/git")
            if sandbox_run "$GIT_PATH" -C "$PROJECT_DIR" status >/dev/null 2>&1; then
                ok "Can run git status in project (at ${GIT_PATH})"
            else
                warn "Cannot run git in project (git may need path adjustment)"
            fi
        fi

        echo ""
        info "=== Denied Access (should fail) ==="
        echo ""

        # ---- Tests that SHOULD FAIL (blocked paths) ----

        # SSH keys
        if sandbox_run /bin/ls "${HOME}/.ssh" >/dev/null 2>&1; then
            fail "CAN read ~/.ssh (should be blocked!)"
        else
            ok "Cannot read ~/.ssh"
        fi

        # Shell history
        if sandbox_run /bin/cat "${HOME}/.zsh_history" >/dev/null 2>&1; then
            fail "CAN read ~/.zsh_history (should be blocked!)"
        else
            ok "Cannot read ~/.zsh_history"
        fi

        # Desktop
        if sandbox_run /bin/ls "${HOME}/Desktop" >/dev/null 2>&1; then
            fail "CAN read ~/Desktop (should be blocked!)"
        else
            ok "Cannot read ~/Desktop"
        fi

        # Documents
        if sandbox_run /bin/ls "${HOME}/Documents" >/dev/null 2>&1; then
            fail "CAN read ~/Documents (should be blocked!)"
        else
            ok "Cannot read ~/Documents"
        fi

        # Downloads
        if sandbox_run /bin/ls "${HOME}/Downloads" >/dev/null 2>&1; then
            fail "CAN read ~/Downloads (should be blocked!)"
        else
            ok "Cannot read ~/Downloads"
        fi

        # Write to Desktop
        if sandbox_run /usr/bin/touch "${HOME}/Desktop/.sandbox-test-$$" 2>/dev/null; then
            rm -f "${HOME}/Desktop/.sandbox-test-$$"
            fail "CAN write to ~/Desktop (should be blocked!)"
        else
            ok "Cannot write to ~/Desktop"
        fi

        # .env file
        if sandbox_run /bin/cat "${HOME}/.env" >/dev/null 2>&1; then
            fail "CAN read ~/.env (should be blocked!)"
        else
            ok "Cannot read ~/.env"
        fi

        # .npmrc
        if sandbox_run /bin/cat "${HOME}/.npmrc" >/dev/null 2>&1; then
            fail "CAN read ~/.npmrc (should be blocked!)"
        else
            ok "Cannot read ~/.npmrc"
        fi

        # Keychain
        if sandbox_run /bin/ls "${HOME}/Library/Keychains" >/dev/null 2>&1; then
            fail "CAN read ~/Library/Keychains (should be blocked!)"
        else
            ok "Cannot read ~/Library/Keychains"
        fi

        # AWS credentials
        if sandbox_run /bin/cat "${HOME}/.aws/credentials" >/dev/null 2>&1; then
            fail "CAN read ~/.aws/credentials (should be blocked!)"
        else
            ok "Cannot read ~/.aws/credentials"
        fi

        # ---- Summary ----
        echo ""
        echo "=============================================="
        echo "  Test Summary"
        echo "=============================================="
        echo ""
        echo -e "  ${GREEN}Passed: ${PASS}${NC}"
        echo -e "  ${RED}Failed: ${FAIL}${NC}"
        echo ""
        if [[ $FAIL -eq 0 ]]; then
            echo -e "  ${GREEN}All checks passed! Sandbox is correctly configured.${NC}"
        else
            echo -e "  ${RED}Some checks failed. Review the sandbox profile.${NC}"
        fi
        echo ""
        echo "=============================================="
        exit $FAIL
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
echo ""

warn "Blocked paths: ~/.ssh, ~/Desktop, ~/Documents, ~/Downloads,"
warn "  ~/Pictures, ~/Movies, ~/Music, ~/.zsh_history, ~/.env,"
warn "  ~/.npmrc, ~/.netrc, ~/.aws, ~/.gnupg, ~/Library/Keychains"
echo ""

sandbox-exec -f "$SANDBOX_PROFILE" \
    -D "HOME=${HOME}" \
    "$CLAUDE_BIN" &

CLAUDE_PID=$!
ok "Claude.app launched (PID: ${CLAUDE_PID})"
echo ""
echo "To stop: kill ${CLAUDE_PID}"
echo "Or just quit Claude.app normally."
