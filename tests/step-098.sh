#!/bin/sh
# Test:
#   Git worktrees: run hooks

# shellcheck disable=SC2086
mkdir -p /tmp/test098/.git/hooks &&
    cd /tmp/test098 &&
    git init &&
    "$GITHOOKS_BIN_DIR/installer" --stdin &&
    git config githooks.autoUpdateEnabled false ||
    exit 1

if ! echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    # When not using core.hooksPath we install into the current repository.
    if ! "$GITHOOKS_BIN_DIR/cli" install --non-interactive; then
        echo "! Install into current repo failed"
        exit 1
    fi
fi

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

git worktree add -b example-a /tmp/test098-A HEAD || exit 2

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

git worktree add -b example-b /tmp/test098-B HEAD || exit 2

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
