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
    git add pre-commit &&
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

git hooks disable --shared 'test-shared' ||
    exit 6

if ! git hooks list | grep 'test-shared' | grep 'shared:local' | grep 'disabled'; then
    git hooks list
    exit 7
fi

git hooks enable --shared 'test-shared' ||
    exit 8

if ! git hooks list | grep 'test-shared' | grep 'shared:local' | grep 'pending'; then
    git hooks list
    exit 9
fi

git hooks accept --shared pre-commit 'test-shared' ||
    exit 10

if ! git hooks list | grep 'test-shared' | grep 'shared:local' | grep 'active'; then
    git hooks list
    exit 11
fi
