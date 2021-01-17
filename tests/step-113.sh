#!/bin/sh
# Test:
#   Test template area is set up properly (regular)

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p "$GH_TEST_TMP/test113/.githooks/pre-commit" &&
    echo "echo 'Testing 113' > '$GH_TEST_TMP/test113.out'" >"$GH_TEST_TMP/test113/.githooks/pre-commit/test-hook" &&
    cd "$GH_TEST_TMP/test113" &&
    git init ||
    exit 1

if grep -r 'github.com/rycus86/githooks' "$GH_TEST_TMP/test113/.git"; then
    echo "! Hooks were installed ahead of time"
    exit 2
fi

mkdir -p ~/.githooks/templates

# run the install, and select installing hooks into existing repos
echo "n
y
$GH_TEST_TMP/test113
" | "$GH_TEST_BIN/installer" --stdin --template-dir ~/.githooks/templates || exit 3

# check if hooks are inside the template folder.
if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep -q "test-hook"; then
    echo "! Hooks were not installed successfully"
    exit 4
fi

git add . && git commit -m 'Test commit' || exit 5

if ! grep 'Testing 113' "$GH_TEST_TMP/test113.out"; then
    echo "! Expected hook did not run"
    exit 6
fi
