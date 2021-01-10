#!/bin/sh
# Test:
#   Direct template execution: test a single pre-commit hook file

mkdir -p /tmp/test12 && cd /tmp/test12 || exit 1
git init || exit 1

mkdir -p .githooks &&
    echo 'echo "Direct execution" > /tmp/test012.out' >.githooks/pre-commit &&
    "$GITHOOKS_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1

grep -q 'Direct execution' /tmp/test012.out
