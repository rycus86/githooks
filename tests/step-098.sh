#!/bin/sh
# Test:
#   Git worktrees: run hooks

SINGLE="--single"
if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    # Do not use single install with core.hooksPath
    SINGLE=""
fi

# shellcheck disable=SC2086
mkdir -p /tmp/test098/.git/hooks &&
    cd /tmp/test098 &&
    git init &&
    /var/lib/githooks/githooks/bin/installer --stdin $SINGLE &&
    git config githooks.autoupdate.enabled false ||
    exit 1

if ! git worktree list >/dev/null 2>/dev/null; then
    echo "Git worktree support is missing"
    exit 249
fi

# shellcheck disable=SC2016
mkdir -p .githooks/pre-commit &&
    echo 'echo p:${PWD} > /tmp/test098.out' >.githooks/pre-commit/test &&
    git add .githooks ||
    exit 1

echo "test" >testing.txt &&
    git add testing.txt ||
    exit 1

ACCEPT_CHANGES=A git commit -m 'testing hooks' || exit 1

if ! grep -q 'p:/tmp/test *098' /tmp/test098.out; then
    echo "! Unexpected target content"
    cat /tmp/test098.out
    exit 1
fi

git worktree add -b example-a /tmp/test098-A master || exit 2

cd /tmp/test098-A &&
    echo "test: A" >testing.txt &&
    git add testing.txt ||
    exit 3

ACCEPT_CHANGES=A git commit -m 'testing hooks (from A)' || exit 3

if ! grep -q 'p:/tmp/test *098-A' /tmp/test098.out; then
    echo "! Unexpected target content"
    cat /tmp/test098.out
    exit 3
fi

git worktree add -b example-b /tmp/test098-B master || exit 2

cd /tmp/test098-B &&
    echo "test: B" >testing.txt &&
    git add testing.txt ||
    exit 4

ACCEPT_CHANGES=A git commit -m 'testing hooks (from B)' || exit 4

if ! grep -q 'p:/tmp/test *098-B' /tmp/test098.out; then
    echo "! Unexpected target content"
    cat /tmp/test098.out
    exit 4
fi
