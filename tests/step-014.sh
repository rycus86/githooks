#!/bin/sh
# Test:
#   Direct template execution: disable running custom hooks

mkdir -p /tmp/test14 && cd /tmp/test14 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo 'exit 1' >.githooks/pre-commit/test &&
    "$GITHOOKS_TEST_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

GITHOOKS_DISABLE=1 "$GITHOOKS_TEST_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1
