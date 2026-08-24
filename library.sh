#!/bin/sh
set -euo pipefail

# Globals
declare -rx DEVCONTAINERD="${HOME}/.devcontainerd"

# Colors for output
declare -r RED='\033[0;31m'
declare -r GREEN='\033[0;32m'
declare -r YELLOW='\033[1;33m'
declare -r BLUE='\033[0;34m'
declare -r NC='\033[0m' # No Color

# Simple Utility functions
log_info() {
  echo -e "${BLUE}[devc]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[devc]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[devc]${NC} $1"
}

log_error() {
  echo -e "${RED}[devc]${NC} $1" >&2
}

pushd() {
    command pushd "$@" > /dev/null
}

popd() {
    command popd "$@" > /dev/null
}

# Meatier Functionality Functions
check_devcontainerd_clean() {
    # Verify the directory exists
    if [ ! -d "$DEVCONTAINERD" ]; then
        mkdir -p "$DEVCONTAINERD"
    fi
    pushd "$DEVCONTAINERD"
    # Make sure it's a work directory
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        git init -q -b main
    fi

    if [ ! -z "$(git status --porcelain)" ]; then
        git status;
        echo ""
        echo "Resource directory directory, please check $DEVCONTAINERD and commit all desirable changes";
        echo ""
        echo "   cd \"$DEVCONTAINERD\" && git status"
        echo ""
        popd
        exit 1;
    fi
    popd
}

check_devcontainer_cli() {
  declare -ra tools=("devcontainer" "rsync" "jq")

  for tool in "${tools[@]}"; do
      if ! hash "$tool" &> /dev/null; then
          log_error "Tool: $tool missing, install via: brew install $tool"
          error="true"
      fi
  done

  if [ -n "${error:-}" ]; then
    exit 1
  fi

  # Check if clean
  check_devcontainerd_clean
  setup_preferences
}

check_no_sys_admin() {
  local workspace="${1:-.}"
  local dc_json="$workspace/.devcontainer/devcontainer.json"
  [[ -f "$dc_json" ]] || return 0
  if jq -e \
    '.runArgs[]? | select(test("SYS_ADMIN"))' \
    "$dc_json" >/dev/null 2>&1; then
    log_error "SYS_ADMIN capability detected in runArgs."
    log_error "This defeats the read-only .devcontainer mount."
    exit 1
  fi
}

commit_to_repository() {
    obj="$1"
    msg="$2"
    pushd "$DEVCONTAINERD"
    if [ ! -z "$(git status --porcelain)" ]; then
        git add "$obj"
        git commit --no-gpg-sign -m "devc: $msg"
        log_info "commit($obj): $msg"
    else
        log_info "commit($obj): already clean, skipping"
    fi
    popd
}

ensure_default() {
    local src="${1}"
    local area="${2}"
    local obj="${3}"
    local ref="${area}/$obj"
    local dst="${DEVCONTAINERD}/${ref}"

    # Skip if exists
    if [ -e "$dst" ]; then
        log_info "ensure_default($ref) already exists, skipping"
        return
    fi

    # Handle directories
    realsrc="$(realpath "$src")"
    if [ -d "$realsrc" ]; then
        dst="$(dirname "$dst")/"
    fi

    # Copy to the repository
    safe_clone "$src" "$dst"
    commit_to_repository "$ref" "ensure_default($ref) added to the repository"
}

ensure_file() {
    local file="$1"
    test -f "$file" || touch "$file"
}

relpath_from_home() {
    local src="$1"
    local res_path="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
    local rel_path="${res_path#"$HOME/"}"
    echo "$rel_path"
}

initialize_from_home() {
    local obj="${1}"
    ensure_default "${HOME}/${obj}" "files" "$obj"
}

safe_clone() {
    local src="$1"
    local dst="$2"

    log_info "safe_clone() $src -> $dst"

    #
    # Skip if the target doesn't exist
    if [ ! -e "$src" ]; then
        log_info "safe_clone($src) doesn't exist, skipping"
        return
    fi
    local realsrc="$(realpath "$src")"
    local realdst="$dst"
    if [ "$(basename "$dst")" = "$(basename "$src")" ]; then
        realdst="$(dirname "$dst")"
    fi

    # Make sure the parent directory exists
    mkdir -p "$(dirname "$dst")"
    if [ -d "$realsrc" ]; then
        rsync -vrpL --delete --exclude=.git "$src" "$realdst/"
    elif [ -f "$realsrc" ]; then
        cp -L "$src" "$realdst/"
    else
        log_error "safe_clone($src) real source '$realsrc' is not a file or directory"
        exit 1;
    fi
}

setup_preferences() {
    initialize_from_home ".gitconfig"
    mkdir -p "$HOME/.claude/skills"
    initialize_from_home ".claude/skills"
    mkdir -p "$DEVCONTAINERD/features"
    ensure_default "$SCRIPT_DIR/personal-feature" "features" "personal-feature"
}

