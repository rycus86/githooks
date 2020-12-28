#!/bin/sh
# Test:
#   Cli tool: list current hooks

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

mkdir -p /tmp/test053/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test053/.githooks/pre-commit/example &&
    cd /tmp/test053 &&
    git init ||
    exit 1

if ! git hooks list | grep "\\- example" | grep "pending"; then
    echo "! Unexpected cli list output"
    exit 1
fi

git commit -m ''

if ! git hooks list | grep "\\- example" | grep "active"; then
    echo "! Unexpected cli list output"
    exit 1
fi

if ! git hooks list; then
    echo "! The Git alias integration failed"
    exit 1
fi
