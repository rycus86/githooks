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
' | "$GITHOOKS_BIN_DIR/installer" --stdin --use-core-hookspath --template-dir ~/.githooks/templates || exit 3

# check if hooks are inside the template folder.
if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep -q "test-hook"; then
    echo "! Hooks were not installed successfully"
    exit 4
fi

git add . && git commit -m 'Test commit' || exit 5

if ! grep 'Testing 114' /tmp/test114.out; then
    echo "! Expected hook did not run"
    exit 6
fi

# Reset to trigger update
if ! (cd ~/.githooks/release && git reset --hard HEAD~1 >/dev/null); then
    echo "! Could not reset master to trigger update."
    exit 1
fi

rm -rf ~/.githooks/templates/hooks/* # Remove to see if the correct folder gets choosen

if ! git hooks update; then
    echo "! Failed to run the update"
    exit 1
fi

if [ ! -f ~/.githooks/templates/hooks/pre-commit ]; then
    echo "! Expected update to install wrappers into \`~/.githooks/templates\`"
    exit 1
fi
