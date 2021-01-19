#!/bin/sh
# Test:
#   Direct template execution: break on errors

mkdir -p "$GH_TEST_TMP/test13" && cd "$GH_TEST_TMP/test13" || exit 1
git init || exit 1

mkdir -p .githooks &&
    echo 'exit 1' >.githooks/pre-commit &&
    "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

rm .githooks/pre-commit &&
    mkdir .githooks/pre-commit &&
    echo 'exit 1' >.githooks/pre-commit/test &&
    "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

echo 'exit 0' >.githooks/pre-commit/test &&
    "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1
