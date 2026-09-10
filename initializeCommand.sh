#!/bin/bash
#
SOURCE="$(realpath "$(which devc)")"
SCRIPT_DIR="$(dirname "$SOURCE")"
. "$SCRIPT_DIR/library.sh"

check_devcontainerd_clean
setup_preferences
