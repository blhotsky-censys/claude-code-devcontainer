#!/bin/bash
#
set -euo pipefail

# Silence, fools!
pushd() {
    command pushd "$@" > /dev/null
}

popd() {
    command popd "$@" > /dev/null
}

ensure_file() {
    file="$1"
    test -f "$file" || touch "$file"
}

DEVCONTAINERD="${HOME}/.devcontainerd"

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
        echo "Resource directory directory, please check $DEVCONTAINERD and commit all desirable changes";
        popd
        exit 1;
    fi
    popd
}

check_devcontainerd_clean

ensure_file "$HOME/.gitconfig"
