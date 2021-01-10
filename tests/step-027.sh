#!/bin/sh
# Test:
#   Direct template execution: do not run disabled hooks

mkdir -p /tmp/test27 && cd /tmp/test27 || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo 'echo "First execution" >> /tmp/test027.out' >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=D "$GITHOOKS_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if grep -q "First execution" /tmp/test027.out; then
    echo "! Expected to refuse executing the hook the first time"
    exit 1
fi

if ! grep -q "pre-commit/test" .git/.githooks.ignore.yaml; then
    echo "! Expected to disable the hook"
    exit 1
fi

echo 'echo "Second execution" >> /tmp/test027.out' >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=Y "$GITHOOKS_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if grep -q "Second execution" /tmp/test027.out; then
    echo "! Expected to refuse executing the hook the second time"
    exit 1
fi
