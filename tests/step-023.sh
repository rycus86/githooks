#!/bin/sh
# Test:
#   Run an install with multiple shared hooks set up, and verify those trigger properly

mkdir -p "$GH_TEST_TMP/shared/hooks-023-a.git/pre-commit" &&
    echo "echo 'From shared hook A' >> '$GH_TEST_TMP/test-023.out'" \
        >"$GH_TEST_TMP/shared/hooks-023-a.git/pre-commit/say-hello" &&
    cd "$GH_TEST_TMP/shared/hooks-023-a.git" &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p "$GH_TEST_TMP/shared/hooks-023-b.git/pre-commit" &&
    echo "echo 'From shared hook B' >> '$GH_TEST_TMP/test-023.out'" \
        >"$GH_TEST_TMP/shared/hooks-023-b.git/pre-commit/say-hello" &&
    cd "$GH_TEST_TMP/shared/hooks-023-b.git" &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

# change it and expect it to change it back
git config --global githooks.shared "$GH_TEST_TMP/shared/some-previous-example"

# run the install, and set up shared repos
if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "n
y
$GH_TEST_TMP/shared/hooks-023-a.git
$GH_TEST_TMP/shared/hooks-023-b.git
" | "$GH_TEST_BIN/installer" --stdin || exit 1

else
    echo "n
n
y
$GH_TEST_TMP/shared/hooks-023-a.git
$GH_TEST_TMP/shared/hooks-023-b.git
" | "$GH_TEST_BIN/installer" --stdin || exit 1

fi

git config --global --get-all githooks.shared | grep -v 'some-previous-example' || exit 1

mkdir -p "$GH_TEST_TMP/test023" && cd "$GH_TEST_TMP/test023" || exit 1
git init || exit 1

# verify that the hooks are installed and are working
git commit -m '' 2>/dev/null

if ! grep 'From shared hook A' "$GH_TEST_TMP/test-023.out"; then
    echo "! The shared hooks A don't seem to be working"
    exit 1
fi

if ! grep 'From shared hook B' "$GH_TEST_TMP/test-023.out"; then
    echo "! The shared hooks B don't seem to be working"
    exit 1
fi
