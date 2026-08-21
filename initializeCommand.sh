#!/bin/bash
#
SOURCE="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SOURCE")"
. "$SCRIPT_DIR/library.sh"

check_devcontainerd_clean

ensure_file "$HOME/.gitconfig"
