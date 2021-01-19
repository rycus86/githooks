#!/bin/sh
# Test:
#   Run an install that preserves an existing hook in an existing repo

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p "$GH_TEST_TMP/test9/.githooks/pre-commit" &&
    cd "$GH_TEST_TMP/test9" &&
    echo "echo 'In-repo' >> '$GH_TEST_TMP/test-009.out'" >.githooks/pre-commit/test &&
    git init &&
    mkdir -p .git/hooks &&
    echo '#!/bin/sh' >>.git/hooks/pre-commit &&
    echo "echo 'Previous' >> '$GH_TEST_TMP/test-009.out'" >>.git/hooks/pre-commit &&
    chmod +x .git/hooks/pre-commit ||
    exit 1

echo "n
y
$GH_TEST_TMP/test9
" | "$GH_TEST_BIN/installer" --stdin || exit 1

git commit -m ''

if ! grep 'Previous' "$GH_TEST_TMP/test-009.out"; then
    echo '! Saved hook was not run'
    exit 1
fi

if ! grep 'In-repo' "$GH_TEST_TMP/test-009.out"; then
    echo '! Newly added hook was not run'
    exit 1
fi
