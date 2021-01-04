#!/bin/sh
# Test:
#   Test template area is set up properly (regular)

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test113/.githooks/pre-commit &&
    echo 'echo "Testing 113" > /tmp/test113.out' >/tmp/test113/.githooks/pre-commit/test-hook &&
    cd /tmp/test113 &&
    git init ||
    exit 1

if grep -r 'github.com/rycus86/githooks' /tmp/test113/.git; then
    echo "! Hooks were installed ahead of time"
    exit 2
fi

mkdir -p ~/.githooks/templates

# run the install, and select installing hooks into existing repos
echo 'n
y
/tmp/test113
' | "$GITHOOKS_BIN_DIR/installer" --stdin --template-dir ~/.githooks/templates || exit 3

# check if hooks are inside the template folder.
if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep -q "test-hook"; then
    echo "! Hooks were not installed successfully"
    exit 4
fi

git add . && git commit -m 'Test commit' || exit 5

if ! grep 'Testing 113' /tmp/test113.out; then
    echo "! Expected hook did not run"
    exit 6
fi
