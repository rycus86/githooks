#!/bin/sh
# Test:
#   Direct template execution: test pre-commit hooks

mkdir -p "$GH_TEST_TMP/test11" && cd "$GH_TEST_TMP/test11" || exit 1
git init || exit 1

# set a non existing githooks.runner
git config githooks.runner "nonexisting-binary"
OUT=$("$GH_TEST_REPO/githooks/run-wrapper.sh" 2>&1)

if ! echo "$OUT" | grep -q "Githooks runner points to a non existing location"; then
    echo "! Expected wrapper template to fail" >&2
    exit 1
fi

git config --unset githooks.runner

mkdir -p .githooks/pre-commit &&
    echo "echo 'Direct execution' > '$GH_TEST_TMP/test011.out'" >.githooks/pre-commit/test &&
    "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1

grep -q 'Direct execution' "$GH_TEST_TMP/test011.out"
