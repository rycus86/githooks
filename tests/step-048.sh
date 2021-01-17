#!/bin/sh
# Test:
#   Direct template execution: do not run any hooks in any repos

git config --global githooks.disable true || exit 1

mkdir -p "$GH_TEST_TMP/test48" && cd "$GH_TEST_TMP/test48" || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo "echo 'Accepted hook' > '$GH_TEST_TMP/test48.out'" >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=Y \
        "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if [ -f "$GH_TEST_TMP/test48.out" ]; then
    echo "! Hook was unexpectedly run"
    exit 1
fi

git config --global --unset githooks.disable || exit 1

echo "echo 'Changed hook' > '$GH_TEST_TMP/test48.out'" >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=Y \
        "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "Changed hook" "$GH_TEST_TMP/test48.out"; then
    echo "! Changed hook was not run"
    exit 1
fi
