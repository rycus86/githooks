#!/bin/sh
# Test:
#   Execute a dry-run, non-interactive installation

mkdir -p "$GH_TEST_TMP/test33/a" && cd "$GH_TEST_TMP/test33/a" || exit 1
git init || exit 1

"$GH_TEST_BIN/installer" --dry-run --non-interactive || exit 1

mkdir -p "$GH_TEST_TMP/test33/b" && cd "$GH_TEST_TMP/test33/b" || exit 1
git init || exit 1

if grep -q 'https://github.com/rycus86/githooks' "$GH_TEST_TMP/test33/a/.git/hooks/pre-commit"; then
    echo "! Hooks are unexpectedly installed in A"
    exit 1
fi

if grep -q 'https://github.com/rycus86/githooks' "$GH_TEST_TMP/test33/b/.git/hooks/pre-commit"; then
    echo "! Hooks are unexpectedly installed in B"
    exit 1
fi
