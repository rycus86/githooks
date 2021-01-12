#!/bin/sh
# Test:
#   Test registering mechanism.

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

REGISTER_FILE=~/.githooks/registered.yaml

if grep -q "/" "$REGISTER_FILE"; then
    echo "Expected the file to not contain any paths"
    exit 1
fi

# Test that first git action registers repo 1
mkdir -p /tmp/test116.1 && cd /tmp/test116.1 &&
    git init &&
    git commit --allow-empty -m 'Initial commit' ||
    exit 1

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    if grep -q "/" "$README_FILE"; then
        echo "Expected the file to contain any paths"
        exit 1
    fi
    # Skip further tests, because it does not apply for core hooks path
    exit 0
fi

if [ ! -f "$REGISTER_FILE" ]; then
    echo "Expected the file to be created"
    exit 1
fi

if ! grep -q /tmp/test116.1/.git "$REGISTER_FILE"; then
    echo "Expected correct content"
    cat "$REGISTER_FILE"
    exit 2
fi

# Test that a first git action registers repo 2
# and repo 1 ist still registered
mkdir -p /tmp/test116.2 && cd /tmp/test116.2 &&
    git init &&
    git commit --allow-empty -m 'Initial commit' ||
    exit 1

if ! grep -q /tmp/test116.1/.git "$REGISTER_FILE" ||
    ! grep -q /tmp/test116.2/.git "$REGISTER_FILE"; then
    echo "! Expected correct content"
    cat "$REGISTER_FILE"
    exit 3
fi

# Test install to all repos 1,2,3
mkdir -p /tmp/test116.3 && cd /tmp/test116.3 && git init

echo 'Y
/tmp
' | "$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

if ! grep -q /tmp/test116.1/.git "$REGISTER_FILE" ||
    ! grep -q /tmp/test116.2/.git "$REGISTER_FILE" ||
    ! grep -q /tmp/test116.3/.git "$REGISTER_FILE"; then
    echo "! Expected all repos to be registered"
    cat "$REGISTER_FILE"
    exit 4
fi

# Test uninstall to only repo 1
cd /tmp/test116.1 || exit 1
if ! "$GITHOOKS_BIN_DIR/cli" uninstall --non-interactive; then
    echo "! Uninstall from current repo failed"
    exit 1
fi

if grep -q /tmp/test116.1 "$REGISTER_FILE" ||
    (! grep -q /tmp/test116.2 "$REGISTER_FILE" &&
        ! grep -q /tmp/test116.3 "$REGISTER_FILE"); then
    echo "! Expected repo 2 and 3 to still be registered"
    cat "$REGISTER_FILE"
    exit 5
fi

# Test total uninstall to all repos
echo 'Y
/tmp
' | "$GITHOOKS_BIN_DIR/uninstaller" --stdin || exit 1

if [ -f "$REGISTER_FILE" ]; then
    echo "! Expected registered list to not exist"
    exit 1
fi

if [ -f "$GITHOOKS_INSTALL_BIN_DIR/uninstaller" ] ||
    [ -f "$GITHOOKS_INSTALL_BIN_DIR/installer" ] ||
    [ -f "$GITHOOKS_INSTALL_BIN_DIR/runner" ] ||
    [ -f "$GITHOOKS_INSTALL_BIN_DIR/cli" ]; then
    echo "! Expected that all binaries are deleted."
    exit 1
fi

# Reinstall everywhere
echo 'Y
y
/tmp
' | "$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

# Update Test
# Set all other hooks to dirty by adding something
# shellcheck disable=SC2156
find /tmp -type f -path "*/.git/hooks/*" -exec sh -c "echo 'Add DIRTY to {}' && echo '#DIRTY' >>'{}'" \; || exit 1
find /tmp -type f -path "*/.git/hooks/*" |
    while read -r HOOK; do
        if ! grep -q "#DIRTY" "$HOOK"; then
            echo "! Expected hooks to be dirty"
            exit 1
        fi
    done || exit 1

# Trigger the update only from repo 3
CURRENT_TIME=$(date +%s)
MOCK_LAST_RUN=$((CURRENT_TIME - 100000))

# Reset to trigger update from repo 3
if ! (cd ~/.githooks/release && git reset --hard HEAD~1 >/dev/null); then
    echo "! Could not reset master to trigger update."
    exit 1
fi

cd /tmp/test116.3 &&
    git config --global githooks.autoUpdateEnabled true &&
    git config --global githooks.autoUpdateCheckTimestamp $MOCK_LAST_RUN &&
    git commit --allow-empty -m 'Second commit' || exit 1

# Check that all hooks are updated
find /tmp -type f -path "*/.git/hooks/*" -and -not -name "*disabled*" |
    while read -r HOOK; do
        if grep -q "#DIRTY" "$HOOK" && ! echo "$HOOK" | grep -q ".4"; then
            echo "! Expected hooks to be updated $HOOK"
            exit 1
        fi
    done || exit 1
