#!/bin/sh
# Test:
#   Disable, enable and accept a shared hook

git config --global githooks.testingTreatFileProtocolAsRemote "true"

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test112.shared/shared-repo.git/.githooks/pre-commit &&
    cd /tmp/test112.shared/shared-repo.git &&
    git init &&
    echo 'echo "Shared invoked" > /tmp/test112.out' >.githooks/pre-commit/test-shared &&
    git add .githooks &&
    git commit -m 'Initial commit' ||
    exit 2

mkdir -p /tmp/test112.repo &&
    cd /tmp/test112.repo &&
    git init ||
    exit 3

git hooks shared add --shared file:///tmp/test112.shared/shared-repo.git &&
    git hooks shared list | grep "shared-repo" | grep "pending" &&
    git hooks shared pull ||
    exit 4

if ! git hooks list | grep 'test-shared' | grep 'shared:local' | grep 'pending'; then
    git hooks list
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
