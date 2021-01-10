#!/bin/sh
# Test:
#   Cli tool: print help and usage

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

if ! "$GITHOOKS_BIN_DIR/cli" --help | grep -q "See further information at"; then
    echo "! Unexpected cli help output"
    exit 1
fi
