#!/bin/sh
# Test:
#   Cli tool: list shows files in trusted repos

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

mkdir -p /tmp/test060/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test060/.githooks/pre-commit/first &&
    echo 'echo "Hello"' >/tmp/test060/.githooks/pre-commit/second &&
    touch /tmp/test060/.githooks/trust-all &&
    cd /tmp/test060 &&
    git init &&
    git config --local githooks.trust.all true ||
    exit 1

if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep "first" | grep -q "'trusted'"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep "second" | grep -q "'trusted'"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi
