#!/bin/sh
# Test:
#   Disable, enable and accept a shared hook

git config --global githooks.testingTreatFileProtocolAsRemote "true"

if ! "$GITHOOKS_BIN_DIR/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test112.shared/shared-repo.git/.githooks/pre-commit &&
    cd /tmp/test112.shared/shared-repo.git &&
    git init &&
    echo 'echo "Shared invoked" > /tmp/test112.out' >.githooks/pre-commit/test-shared &&
    echo "mygagahooks" >.githooks/.namespace &&
    git add .githooks &&
    git commit -m 'Initial commit' ||
    exit 2

mkdir -p /tmp/test112.repo &&
    cd /tmp/test112.repo &&
    git init ||
    exit 3

"$GITHOOKS_INSTALL_BIN_DIR/cli" shared add --shared file:///tmp/test112.shared/shared-repo.git || exit 41
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared list | grep "shared-repo" | grep "'pending'" || exit 42
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared update || exit 43

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep 'test-shared' | grep 'shared:repo' | grep "'active'" | grep "'untrusted'"; then
    "$GITHOOKS_INSTALL_BIN_DIR/cli" list
    exit 5
fi

"$GITHOOKS_INSTALL_BIN_DIR/cli" ignore add --pattern 'mygagahooks/**/test-shared' ||
    exit 6

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep 'test-shared' |
    grep "'shared:repo'" | grep "'ignored'" | grep -q "'untrusted'"; then
    echo "! Failed to ignore shared hook"
    exit 7
fi

"$GITHOOKS_INSTALL_BIN_DIR/cli" ignore add --pattern '!**/test-shared' ||
    exit 8

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep 'test-shared' |
    grep "'shared:repo'" | grep "'active'" | grep -q "'untrusted'"; then
    echo "! Failed to activate shared hook"
    exit 7
fi

"$GITHOOKS_INSTALL_BIN_DIR/cli" trust hooks --pattern '**/test-shared' ||
    exit 10

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep 'test-shared' |
    grep "'shared:repo'" | grep "'active'" | grep -q "'trusted'"; then
    echo "! Failed to trust shared hook"
    exit 7
fi
