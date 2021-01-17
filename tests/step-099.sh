#!/bin/sh
# Test:
#   Git worktrees: list hooks

"$GITHOOKS_TEST_BIN_DIR/installer" || exit 1

mkdir -p /tmp/test099/.git/hooks &&
    cd /tmp/test099 &&
    git init &&
    git config githooks.autoUpdateEnabled false ||
    exit 1

if ! git worktree list >/dev/null 2>/dev/null; then
    echo "Git worktree support is missing"
    exit 1
fi

# shellcheck disable=SC2016
mkdir -p .githooks/pre-commit &&
    echo 'echo p:${PWD} > /tmp/test099.out' >.githooks/pre-commit/example &&
    git add .githooks ||
    exit 1

echo "test" >testing.txt &&
    git add testing.txt ||
    exit 1

ACCEPT_CHANGES=A git commit -m 'testing hooks' || exit 1

if [ ! -f "/tmp/test099.out" ]; then
    echo "! Expected hook to run"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "example" | grep "'active'" | grep -q "'trusted'"; then
    echo "! Unexpected cli list output"
    "$GITHOOKS_INSTALL_BIN_DIR/cli" list
    exit 3
fi

# Worktrees have their own trust store...
git worktree add -b example-a ../test099-A HEAD || exit 2
cd ../test099-A || exit 2

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "example" | grep "'active'" | grep -q "'untrusted'"; then
    echo "! Unexpected cli list output"
    "$GITHOOKS_INSTALL_BIN_DIR/cli" list
    exit 3
fi
