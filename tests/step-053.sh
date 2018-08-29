#!/bin/sh
# Test:
#   Cli tool: list current hooks

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test053/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test053/.githooks/pre-commit/example &&
    cd /tmp/test053 &&
    git init ||
    exit 1

if ! sh /var/lib/githooks/cli.sh list | grep "\\- example" | grep "pending"; then
    echo "! Unexpected cli list output"
    exit 1
fi

git commit -m ''

if ! sh /var/lib/githooks/cli.sh list | grep "\\- example" | grep "active"; then
    echo "! Unexpected cli list output"
    exit 1
fi

if ! git hooks list; then
    echo "! The Git alias integration failed"
    exit 1
fi
