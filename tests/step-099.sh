#!/bin/sh
# Test:
#   Git worktrees: list hooks

mkdir -p /tmp/test099/.git/hooks &&
    cd /tmp/test099 &&
    git init &&
    "$GITHOOKS_BIN_DIR/installer" --stdin &&
    git config githooks.autoupdate.enabled false ||
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

git worktree add -b example-a ../test099-A HEAD || exit 2
cd ../test099-A || exit 2

if ! "$GITHOOKS_EXE_GIT_HOOKS" list | grep "example" | grep "'active'" | grep -q "'untrusted'"; then
    echo "! Unexpected cli list output"
    exit 3
fi
