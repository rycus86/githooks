#!/bin/sh
# Test:
#   Cli tool: run forced update

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test062 &&
    cd /tmp/test062 &&
    git init ||
    exit 1

if ! git hooks update force; then
    echo "! Failed to run the update"
    exit 1
fi

if git hooks update unknown; then
    echo "! Expected to fail on unknown operation"
    exit 1
fi

if ! git hooks update force; then
    echo "! The Git alias integration failed"
    exit 1
fi
