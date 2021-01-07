#!/bin/sh
# Test:
#   Cli tool: print version number

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

if ! "$GITHOOKS_EXE_GIT_HOOKS" version | grep -qE ".*\d+\.\d+\.\d+-.*"; then
    echo "! Unexpected cli version output"
    exit 1
fi
