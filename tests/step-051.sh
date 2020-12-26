#!/bin/sh
# Test:
#   Cli tool: print version number

/var/lib/githooks/githooks/bin/installer --stdin || exit 1

if ! git hooks version | grep -q "Version: "; then
    echo "! Unexpected cli version output"
    exit 1
fi

if ! git hooks version; then
    echo "! The Git alias integration failed"
    exit 1
fi
