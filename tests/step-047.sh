#!/bin/sh
# Test:
#   Direct template execution: do not run any hooks in the current repo

mkdir -p "$GH_TEST_TMP/test47" && cd "$GH_TEST_TMP/test47" || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    git config githooks.disable Y &&
    echo "echo 'Accepted hook' > '$GH_TEST_TMP/test47.out'" >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=Y \
        "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if [ -f "$GH_TEST_TMP/test47.out" ]; then
    echo "! Hook was unexpectedly run"
    exit 1
fi

echo "echo 'Changed hook' > '$GH_TEST_TMP/test47.out'" >.githooks/pre-commit/test &&
    git config --unset githooks.disable &&
    ACCEPT_CHANGES=Y \
        "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "Changed hook" "$GH_TEST_TMP/test47.out"; then
    echo "! Changed hook was not run"
    exit 1
fi
