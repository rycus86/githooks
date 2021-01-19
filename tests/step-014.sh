#!/bin/sh
# Test:
#   Direct template execution: disable running custom hooks

mkdir -p "$GH_TEST_TMP/test14" && cd "$GH_TEST_TMP/test14" || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo 'exit 1' >.githooks/pre-commit/test &&
    "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

GITHOOKS_DISABLE=1 "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1
