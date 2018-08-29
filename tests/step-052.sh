#!/bin/sh
# Test:
#   Cli tool: print help and usage

sh /var/lib/githooks/install.sh || exit 1

if ! sh /var/lib/githooks/cli.sh help | grep -q "Prints this help message"; then
    echo "! Unexpected cli help output"
    exit 1
fi

if ! git hooks help; then
    echo "! The Git alias integration failed"
    exit 1
fi
