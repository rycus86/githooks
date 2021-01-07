#!/bin/sh
# Test:
#   Disable, enable and accept a shared hook (no 'githooks' directory)

git config --global githooks.testingTreatFileProtocolAsRemote "true"

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test115.shared/shared-repo.git/pre-commit &&
    cd /tmp/test115.shared/shared-repo.git &&
    git init &&
    echo 'echo "Shared invoked" > /tmp/test115.out' >pre-commit/test-shared &&
    echo "mygagahooks" >.namespace &&
    git add pre-commit .namespace &&
    git commit -m 'Initial commit' ||
    exit 2

mkdir -p /tmp/test115.repo &&
    cd /tmp/test115.repo &&
    git init ||
    exit 3

"$GITHOOKS_EXE_GIT_HOOKS" shared add --shared file:///tmp/test115.shared/shared-repo.git &&
    "$GITHOOKS_EXE_GIT_HOOKS" shared list | grep "shared-repo" | grep "pending" &&
    "$GITHOOKS_EXE_GIT_HOOKS" shared pull || exit 4

if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep 'test-shared' | grep 'shared:repo' | grep "'active'" | grep "'untrusted'"; then
    "$GITHOOKS_EXE_GIT_HOOKS" list
    exit 5
fi

"$GITHOOKS_EXE_GIT_HOOKS" ignore add --pattern 'mygagahooks/**/test-shared' ||
    exit 6

if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep 'test-shared' |
    grep "'shared:repo'" | grep "'ignored'" | grep -q "'untrusted'"; then
    echo "! Failed to ignore shared hook"
    exit 7
fi

"$GITHOOKS_EXE_GIT_HOOKS" ignore add --pattern '!**/test-shared' ||
    exit 8

if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep 'test-shared' |
    grep "'shared:repo'" | grep "'active'" | grep -q "'untrusted'"; then
    echo "! Failed to activate shared hook"
    exit 7
fi

"$GITHOOKS_EXE_GIT_HOOKS" trust hooks --pattern '**/test-shared' ||
    exit 10

if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep 'test-shared' |
    grep "'shared:repo'" | grep "'active'" | grep -q "'trusted'"; then
    echo "! Failed to trust shared hook"
    exit 7
fi
