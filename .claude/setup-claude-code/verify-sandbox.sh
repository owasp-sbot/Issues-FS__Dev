#!/bin/bash
# =============================================================================
# verify-sandbox.sh
# Tests that the sandboxed user has correct permissions
# =============================================================================
# Usage: sudo ./verify-sandbox.sh
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/config.env"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✓ PASS${NC}  $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗ FAIL${NC}  $1"; FAIL=$((FAIL + 1)); }
info() { echo -e "${CYAN}[TEST]${NC} $1"; }

[[ $EUID -ne 0 ]] && { echo "Run with sudo"; exit 1; }

# Verify user exists
info "Checking user exists..."
if dscl . -read "/Users/${CC_USERNAME}" &>/dev/null; then
    pass "User '${CC_USERNAME}' exists"
else
    fail "User '${CC_USERNAME}' does not exist"
    echo "  Run setup-claude-code-user.sh first."
    exit 1
fi

# Verify user is hidden
info "Checking user is hidden..."
HIDDEN=$(dscl . -read "/Users/${CC_USERNAME}" IsHidden 2>/dev/null | awk '{print $2}')
if [[ "$HIDDEN" == "1" ]]; then
    pass "User is hidden from login screen"
else
    fail "User is NOT hidden (IsHidden=$HIDDEN)"
fi

# ---- Filesystem Access Tests ------------------------------------------------
info "Testing R/W directory access..."
IFS=',' read -ra RW_DIRS <<< "$CC_RW_DIRECTORIES"
for dir in "${RW_DIRS[@]}"; do
    dir=$(echo "$dir" | xargs)
    [[ ! -d "$dir" ]] && { fail "R/W dir does not exist: $dir"; continue; }

    # Test read
    if sudo -u "${CC_USERNAME}" ls "$dir" &>/dev/null; then
        pass "Can read: $dir"
    else
        fail "Cannot read: $dir"
    fi

    # Test write
    TESTFILE="${dir}/.sandbox-write-test-$$"
    if sudo -u "${CC_USERNAME}" touch "$TESTFILE" 2>/dev/null; then
        rm -f "$TESTFILE"
        pass "Can write: $dir"
    else
        fail "Cannot write: $dir"
    fi
done

info "Testing R/O directory access..."
IFS=',' read -ra RO_DIRS <<< "$CC_RO_DIRECTORIES"
for dir in "${RO_DIRS[@]}"; do
    dir=$(echo "$dir" | xargs)
    [[ ! -d "$dir" ]] && { fail "R/O dir does not exist: $dir"; continue; }

    # Test read
    if sudo -u "${CC_USERNAME}" ls "$dir" &>/dev/null; then
        pass "Can read: $dir"
    else
        fail "Cannot read: $dir"
    fi

    # Test write (should fail)
    TESTFILE="${dir}/.sandbox-write-test-$$"
    if sudo -u "${CC_USERNAME}" touch "$TESTFILE" 2>/dev/null; then
        rm -f "$TESTFILE"
        fail "CAN write to read-only dir (bad!): $dir"
    else
        pass "Cannot write to R/O dir (good): $dir"
    fi
done

# ---- Negative Tests: directories that should NOT be accessible --------------
info "Testing that sensitive directories are NOT accessible..."

# The main user's home dir should be inaccessible (except ACL'd subdirs)
MAIN_USER_HOME=$(echo "$CC_RW_DIRECTORIES" | sed 's|/Users/\([^/]*\)/.*|\1|' | head -1)
MAIN_USER_HOME="/Users/$(echo "$CC_RW_DIRECTORIES" | cut -d',' -f1 | xargs | sed 's|/Users/||' | cut -d'/' -f1)"

SENSITIVE_DIRS=(
    "${MAIN_USER_HOME}/.ssh"
    "${MAIN_USER_HOME}/.zsh_history"
    "${MAIN_USER_HOME}/Desktop"
    "${MAIN_USER_HOME}/Documents"
    "${MAIN_USER_HOME}/Downloads"
    "/etc/sudoers"
)

for path in "${SENSITIVE_DIRS[@]}"; do
    if sudo -u "${CC_USERNAME}" ls "$path" &>/dev/null; then
        fail "CAN access sensitive path (bad!): $path"
    else
        pass "Cannot access (good): $path"
    fi
done

# ---- Test: wide filesystem search should be restricted ----------------------
info "Testing that broad filesystem search is restricted..."
FOUND_COUNT=$(sudo -u "${CC_USERNAME}" find "${MAIN_USER_HOME}" -maxdepth 1 -type f 2>/dev/null | wc -l | xargs)
if [[ "$FOUND_COUNT" -le 2 ]]; then
    pass "Broad find on home dir returns ≤2 files (restricted)"
else
    fail "Broad find on home dir returns ${FOUND_COUNT} files (too many!)"
fi

# ---- Executable Access Tests ------------------------------------------------
info "Testing restricted bin..."
RESTRICTED_BIN="/Users/${CC_USERNAME}/restricted-bin"
RESTRICTED_PATH="${RESTRICTED_BIN}:/usr/bin:/bin"

IFS=',' read -ra CMDS <<< "$CC_ALLOWED_EXECUTABLES"
for cmd in "${CMDS[@]}"; do
    cmd=$(echo "$cmd" | xargs)
    if [[ -L "${RESTRICTED_BIN}/${cmd}" ]]; then
        pass "Available: ${cmd}"
    else
        fail "Missing from restricted-bin: ${cmd}"
    fi
done

# Test that dangerous commands are NOT available via restricted path
info "Testing that dangerous commands are NOT in restricted bin..."
DANGEROUS_CMDS=("curl" "wget" "ssh" "scp" "brew" "sudo" "su" "nc" "nmap" "dd" "diskutil" "dscl")
for cmd in "${DANGEROUS_CMDS[@]}"; do
    if [[ -L "${RESTRICTED_BIN}/${cmd}" ]] || [[ -f "${RESTRICTED_BIN}/${cmd}" ]]; then
        fail "Dangerous command in restricted-bin: ${cmd}"
    else
        pass "Not available (good): ${cmd}"
    fi
done

# ---- Summary ----------------------------------------------------------------
echo ""
echo "=============================================="
echo "  Verification Summary"
echo "=============================================="
echo ""
echo -e "  ${GREEN}Passed: ${PASS}${NC}"
echo -e "  ${RED}Failed: ${FAIL}${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}All checks passed! Sandbox is correctly configured.${NC}"
else
    echo -e "  ${RED}Some checks failed. Review output above.${NC}"
fi

echo ""
echo "=============================================="
exit $FAIL
