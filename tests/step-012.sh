#!/bin/sh
# Test:
#   Direct template execution: test a single pre-commit hook file

mkdir -p "$GH_TEST_TMP/test12" && cd "$GH_TEST_TMP/test12" || exit 1
git init || exit 1

mkdir -p .githooks &&
    echo "echo 'Direct execution' > '$GH_TEST_TMP/test012.out'" >.githooks/pre-commit &&
    "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1

grep -q 'Direct execution' "$GH_TEST_TMP/test012.out"
