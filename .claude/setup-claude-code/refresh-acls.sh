#!/bin/bash
# =============================================================================
# refresh-acls.sh
# Re-applies ACLs to all directories. Run after creating new project
# directories or if newly created files aren't accessible.
# =============================================================================
# Usage: sudo ./refresh-acls.sh
# =============================================================================

set -euo pipefail

source "$(dirname "$0")/config.env"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }

[[ $EUID -ne 0 ]] && { echo "Run with sudo"; exit 1; }

info "Refreshing R/W ACLs..."
IFS=',' read -ra RW_DIRS <<< "$CC_RW_DIRECTORIES"
for dir in "${RW_DIRS[@]}"; do
    dir=$(echo "$dir" | xargs)
    if [[ -d "$dir" ]]; then
        chmod -R +a "${CC_USERNAME} allow read,write,execute,delete,add_file,add_subdirectory,list,search,file_inherit,directory_inherit" "$dir"
        ok "  R/W: ${dir}"
    else
        warn "  Not found: ${dir}"
    fi
done

info "Refreshing R/O ACLs..."
IFS=',' read -ra RO_DIRS <<< "$CC_RO_DIRECTORIES"
for dir in "${RO_DIRS[@]}"; do
    dir=$(echo "$dir" | xargs)
    if [[ -d "$dir" ]]; then
        chmod -R +a "${CC_USERNAME} allow read,execute,list,search,file_inherit,directory_inherit" "$dir"
        ok "  R/O: ${dir}"
    else
        warn "  Not found: ${dir}"
    fi
done

ok "ACLs refreshed."
