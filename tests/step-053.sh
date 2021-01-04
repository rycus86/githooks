#!/bin/sh
# Test:
#   Cli tool: list current hooks

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

mkdir -p /tmp/test053/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test053/.githooks/pre-commit/example &&
    cd /tmp/test053 &&
    git init ||
    exit 1

if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep "example" | grep "'untrusted'" | grep "'active'"; then
    echo "! Unexpected cli list output"
    exit 1
fi

git commit -m 'Test'

if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep "example" | grep "'trusted'" | grep "'active'"; then
    echo "! Unexpected cli list output"
    exit 1
fi
