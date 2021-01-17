#!/bin/sh
# Test:
#   Direct template execution: test pre-commit hooks

mkdir -p /tmp/test11 && cd /tmp/test11 || exit 1
git init || exit 1

# set a non existing githooks.runner
git config githooks.runner "nonexisting-binary"
OUT=$("$GITHOOKS_TEST_REPO/githooks/run-wrapper.sh" 2>&1)

if ! echo "$OUT" | grep -q "Githooks runner points to a non existing location"; then
    echo "! Expected wrapper template to fail" >&2
    exit 1
fi

git config --unset githooks.runner

mkdir -p .githooks/pre-commit &&
    echo 'echo "Direct execution" > /tmp/test011.out' >.githooks/pre-commit/test &&
    "$GITHOOKS_TEST_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1

grep -q 'Direct execution' /tmp/test011.out
