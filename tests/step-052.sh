#!/bin/sh
# Test:
#   Cli tool: print help and usage

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

if ! git hooks help | grep -q "Prints this help message"; then
    echo "! Unexpected cli help output"
    exit 1
fi
