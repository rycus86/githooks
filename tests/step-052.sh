#!/bin/sh
# Test:
#   Cli tool: print help and usage

"$GH_TEST_BIN/installer" || exit 1

if ! "$GH_TEST_BIN/cli" --help | grep -q "See further information at"; then
    echo "! Unexpected cli help output"
    exit 1
fi
