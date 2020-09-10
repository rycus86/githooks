#!/bin/sh
# Test:
#   Test template area is set up properly (core.hooksPath)

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test114/.githooks/pre-commit &&
    echo 'echo "Testing 114" > /tmp/test114.out' >/tmp/test114/.githooks/pre-commit/test-hook &&
    cd /tmp/test114 &&
    git init ||
    exit 1

if grep -r 'github.com/rycus86/githooks' /tmp/test114/.git; then
    echo "! Hooks were installed ahead of time"
    exit 2
fi

mkdir -p ~/.githooks/templates

# run the install, and select installing hooks into existing repos
echo 'n
y
/tmp/test114
' | sh /var/lib/githooks/install.sh --use-core-hookspath --template-dir ~/.githooks/templates || exit 3

# check if hooks are inside the template folder.
if ! git hooks list | grep test-hook; then
    echo "! Hooks were not installed successfully"
    exit 4
fi

git add . && git commit -m 'Test commit' || exit 5

if ! grep 'Testing 114' /tmp/test114.out; then
    echo "! Expected hook did not run"
    exit 6
fi
