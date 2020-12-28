#!/bin/sh
# Test:
#   Cli tool: list hooks for all types of hook sources

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

mkdir -p ~/.githooks/shared/repo1/.githooks/pre-commit &&
    cd ~/.githooks/shared/repo1 &&
    git init &&
    git remote add origin ssh://git@github.com/test/repo1.git &&
    echo 'echo "Hello"' >~/.githooks/shared/repo1/.githooks/pre-commit/global-pre1 &&
    echo 'echo "Hello"' >~/.githooks/shared/repo1/.githooks/commit-msg &&
    mkdir -p ~/.githooks/shared/repo2/pre-push &&
    cd ~/.githooks/shared/repo2 &&
    git init &&
    git remote add origin https://github.com/test/repo2.git &&
    echo 'echo "Hello"' >~/.githooks/shared/repo2/post-commit &&
    echo 'echo "Hello"' >~/.githooks/shared/repo2/pre-push/global-pre2 ||
    exit 1

git config --global githooks.shared 'ssh://git@github.com/test/repo1.git' || exit 1

mkdir -p /tmp/test055/.githooks/pre-commit &&
    mkdir -p /tmp/test055/.githooks/post-commit &&
    echo 'echo "Hello"' >/tmp/test055/.githooks/pre-commit/local-pre &&
    echo 'echo "Hello"' >/tmp/test055/.githooks/post-commit/local-post &&
    echo 'echo "Hello"' >/tmp/test055/.githooks/post-merge &&
    echo 'https://github.com/test/repo2.git' >/tmp/test055/.githooks/.shared &&
    cd /tmp/test055 &&
    git init &&
    mkdir -p .git/hooks &&
    echo 'echo "Hello"' >.git/hooks/pre-commit.replaced.githook &&
    chmod +x .git/hooks/pre-commit.replaced.githook ||
    exit 1

if ! git hooks list pre-commit | grep -q "previous / file"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! git hooks list pre-commit | grep -q "shared:global"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! git hooks list pre-commit | grep -q "local-pre"; then
    echo "! Unexpected cli list output (3)"
    exit 1
fi

if ! git hooks list commit-msg | grep -q "shared:global"; then
    echo "! Unexpected cli list output (4)"
    exit 1
fi

if ! git hooks list post-commit | grep -q "shared:local"; then
    echo "! Unexpected cli list output (5)"
    exit 1
fi

if ! git hooks list post-commit | grep -q "local-post"; then
    echo "! Unexpected cli list output (6)"
    exit 1
fi

if ! git hooks list post-merge | grep -q "file /"; then
    echo "! Unexpected cli list output (7)"
    exit 1
fi

if ! git hooks list pre-push | grep -q "shared:local"; then
    echo "! Unexpected cli list output (8)"
    exit 1
fi

if ! git hooks list || ! git hooks list pre-commit || ! git hooks list post-commit; then
    echo "! The Git alias integration failed"
    exit 1
fi
