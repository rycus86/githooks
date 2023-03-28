#!/bin/sh
# Test:
#   Cli tool: execute a shared hook on demand

git config --global githooks.testingTreatFileProtocolAsRemote "true"

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test128.shared/shared-repo.git/.githooks/pre-commit &&
    cd /tmp/test128.shared/shared-repo.git &&
    git init &&
    echo 'echo "Shared first"' >.githooks/pre-commit/first.hook &&
    echo 'echo "Shared second"' >.githooks/pre-commit/second &&
    git add .githooks &&
    git commit -m 'Initial commit' ||
    exit 2

mkdir -p /tmp/test128.repo &&
    cd /tmp/test128.repo &&
    git init ||
    exit 3

git hooks shared add --shared file:///tmp/test128.shared/shared-repo.git &&
    git hooks shared list | grep "shared-repo" | grep "pending" &&
    git hooks shared pull ||
    exit 4

if ! git hooks list | grep 'first' | grep 'shared:local' | grep 'pending'; then
    git hooks list
    exit 5
fi

if ! git hooks exec first | grep -q "Shared first"; then
    echo "! Expected output not found (1)"
    exit 6
fi

if ! git hooks exec pre-commit second | grep -q "Shared second"; then
    echo "! Expected output not found (2)"
    exit 7
fi

if ! git hooks exec --exact pre-commit second | grep -q "Shared second"; then
    echo "! Expected output not found (3)"
    exit 8
fi
