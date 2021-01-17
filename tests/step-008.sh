#!/bin/sh
# Test:
#   Run an install that preserves an existing hook in the templates directory

cd /usr/share/git-core/templates/hooks &&
    echo '#!/bin/sh' >>pre-commit &&
    echo "echo 'Previous' >> '$GH_TEST_TMP/test-008.out'" >>pre-commit &&
    chmod +x pre-commit ||
    exit 1

"$GH_TEST_BIN/installer" || exit 1

ls -al /usr/share/git-core/templates/hooks

mkdir -p "$GH_TEST_TMP/test8/.githooks/pre-commit" &&
    cd "$GH_TEST_TMP/test8" &&
    echo "echo 'In-repo' >> '$GH_TEST_TMP/test-008.out'" >.githooks/pre-commit/test &&
    git init ||
    exit 1

git commit -m ''

if ! grep 'Previous' "$GH_TEST_TMP/test-008.out"; then
    echo '! Saved hook was not run'
    exit 1
fi

if ! grep 'In-repo' "$GH_TEST_TMP/test-008.out"; then
    echo '! Newly added hook was not run'
    exit 1
fi
