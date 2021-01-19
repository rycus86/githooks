#!/bin/sh
# Test:
#   Run an install with shared hooks set up, and verify those trigger properly

mkdir -p "$GH_TEST_TMP/shared/hooks-005.git/pre-commit" &&
    echo "echo 'From shared hook' > '$GH_TEST_TMP/test-005.out'" \
        >"$GH_TEST_TMP/shared/hooks-005.git/pre-commit/say-hello" || exit 1

cd "$GH_TEST_TMP/shared/hooks-005.git" &&
    git init &&
    git add . &&
    git commit -m 'Initial commit'

# run the install, and set up shared repos
if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "n
y
$GH_TEST_TMP/shared/hooks-005.git
" | "$GH_TEST_BIN/installer" --stdin || exit 1

else
    echo "n
n
y
$GH_TEST_TMP/shared/hooks-005.git
" | "$GH_TEST_BIN/installer" --stdin || exit 1

fi

mkdir -p "$GH_TEST_TMP/test5" && cd "$GH_TEST_TMP/test5" || exit 1
git init || exit 1

# verify that the hooks are installed and are working
git commit -m '' 2>/dev/null

if ! grep 'From shared hook' "$GH_TEST_TMP/test-005.out"; then
    echo "! The shared hooks don't seem to be working"
    exit 1
fi
