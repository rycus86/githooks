#!/bin/sh
# Test:
#   Direct template execution: do not trust the repository

mkdir -p "$GH_TEST_TMP/test35" && cd "$GH_TEST_TMP/test35" || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    touch .githooks/trust-all &&
    echo "echo 'Accepted hook' > '$GH_TEST_TMP/test35.out'" >.githooks/pre-commit/test &&
    TRUST_ALL_HOOKS=N ACCEPT_CHANGES=Y \
        "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "Accepted hook" "$GH_TEST_TMP/test35.out"; then
    echo "! Expected hook was not run"
    exit 1
fi

echo "echo 'Changed hook' > '$GH_TEST_TMP/test35.out'" >.githooks/pre-commit/test &&
    TRUST_ALL_HOOKS="" ACCEPT_CHANGES=N \
        "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if grep -q "Changed hook" "$GH_TEST_TMP/test35.out"; then
    echo "! Changed hook was unexpectedly run"
    exit 1
fi

if ! CFG=$(git config --get githooks.trustAll) || [ "$CFG" != "false" ]; then
    echo "! Unexpected config found"
    exit 1
fi
