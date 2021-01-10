#!/bin/sh
# Test:
#   Direct template execution: update a hook in a trusted repository

mkdir -p /tmp/test34 && cd /tmp/test34 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    touch .githooks/trust-all &&
    echo 'echo "Trusted hook" > /tmp/test34.out' >.githooks/pre-commit/test &&
    TRUST_ALL_HOOKS=Y ACCEPT_CHANGES=N \
        "$GITHOOKS_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "Trusted hook" /tmp/test34.out; then
    echo "! Expected hook was not run"
    exit 1
fi

echo 'echo "Changed hook" > /tmp/test34.out' >.githooks/pre-commit/test &&
    TRUST_ALL_HOOKS="" ACCEPT_CHANGES=N \
        "$GITHOOKS_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "Changed hook" /tmp/test34.out; then
    echo "! Changed hook was not run"
    exit 1
fi
