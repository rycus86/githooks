#!/bin/sh
# Test:
#   Run a simple install and verify multiple hooks trigger properly

# run the default install
"$GH_TEST_BIN/installer" || exit 1

mkdir -p "$GH_TEST_TMP/test3" && cd "$GH_TEST_TMP/test3" || exit 1
git init || exit 1

# set up 2 pre-commit hooks, execute them and verify that they worked
mkdir -p .githooks/pre-commit &&
    echo "echo 'Hook-1' >> '$GH_TEST_TMP/multitest'" >.githooks/pre-commit/test1 &&
    echo "echo 'Hook-2' >> '$GH_TEST_TMP/multitest'" >.githooks/pre-commit/test2 ||
    exit 1

git commit -m '' 2>/dev/null

grep -q 'Hook-1' "$GH_TEST_TMP/multitest" && grep -q 'Hook-2' "$GH_TEST_TMP/multitest"
