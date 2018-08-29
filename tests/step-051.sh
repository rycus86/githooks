#!/bin/sh
# Test:
#   Cli tool: print version number

sh /var/lib/githooks/install.sh || exit 1

if ! sh /var/lib/githooks/cli.sh version | grep -q "Version: "; then
    echo "! Unexpected cli version output"
    exit 1
fi

if ! git hooks version; then
    echo "! The Git alias integration failed"
    exit 1
fi
