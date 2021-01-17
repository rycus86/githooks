#!/bin/sh
# Test:
#   Direct template execution: break on errors

mkdir -p /tmp/test13 && cd /tmp/test13 || exit 1
git init || exit 1

mkdir -p .githooks &&
    echo 'exit 1' >.githooks/pre-commit &&
    "$GITHOOKS_TEST_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

rm .githooks/pre-commit &&
    mkdir .githooks/pre-commit &&
    echo 'exit 1' >.githooks/pre-commit/test &&
    "$GITHOOKS_TEST_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

echo 'exit 0' >.githooks/pre-commit/test &&
    "$GITHOOKS_TEST_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1
