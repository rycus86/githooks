#!/bin/sh
# Test:
#   Run a simple install and verify a hook triggers properly

# run the default install
"$GH_TEST_BIN/installer" || exit 1

mkdir -p "$GH_TEST_TMP/test2" && cd "$GH_TEST_TMP/test2" || exit 1
git init || exit 1

# add a pre-commit hook, execute and verify that it worked
mkdir -p .githooks/pre-commit &&
    echo "echo 'From githooks' > '$GH_TEST_TMP/hooktest'" >.githooks/pre-commit/test ||
    exit 1

git commit -m '' 2>/dev/null

grep -q 'From githooks' "$GH_TEST_TMP/hooktest"
