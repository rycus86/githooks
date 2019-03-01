#!/bin/sh
# Test:
#   Git worktrees: list hooks

mkdir -p /tmp/test099/.git/hooks &&
    cd /tmp/test099 &&
    git init &&
    sh /var/lib/githooks/install.sh --single &&
    git config githooks.autoupdate.enabled N ||
    exit 1

if ! git worktree list >/dev/null 2>/dev/null; then
    echo "Git worktree support is missing"
    exit 249
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

git worktree add -b example-a ../test099-A master || exit 2
cd ../test099-A || exit 2

if ! sh /var/lib/githooks/cli.sh list | grep "example" | grep -q "pending"; then
    echo "! Unexpected cli list output"
    exit 3
fi

if ! git hooks list; then
    echo "! The Git alias integration failed"
    exit 4
fi
