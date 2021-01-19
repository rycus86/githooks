#!/bin/sh
# Test:
#   Direct template execution: do not run disabled hooks

mkdir -p "$GH_TEST_TMP/test27" && cd "$GH_TEST_TMP/test27" || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo "echo 'First execution' >> '$GH_TEST_TMP/test027.out'" >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=D "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if grep -q "First execution" "$GH_TEST_TMP/test027.out"; then
    echo "! Expected to refuse executing the hook the first time"
    exit 1
fi

if ! grep -q "pre-commit/test" .git/.githooks.ignore.yaml; then
    echo "! Expected to disable the hook"
    exit 1
fi

echo "echo 'Second execution' >> '$GH_TEST_TMP/test027.out'" >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=Y "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if grep -q "Second execution" "$GH_TEST_TMP/test027.out"; then
    echo "! Expected to refuse executing the hook the second time"
    exit 1
fi
