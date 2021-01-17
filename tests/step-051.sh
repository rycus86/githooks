#!/bin/sh
# Test:
#   Cli tool: print version number

"$GH_TEST_BIN/installer" || exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" --version | grep -qE ".*\d+\.\d+\.\d+"; then
    echo "! Unexpected cli version output"
    exit 1
fi
