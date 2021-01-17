#!/bin/sh
# Test:
#   Run a simple install non-interactively and verify the hooks are in place

# run the default install
"$GH_TEST_BIN/installer" --non-interactive || exit 1

mkdir -p "$GH_TEST_TMP/test1" && cd "$GH_TEST_TMP/test1" || exit 1
git init || exit 1

# verify that the pre-commit is installed
grep -q 'https://github.com/rycus86/githooks' .git/hooks/pre-commit
