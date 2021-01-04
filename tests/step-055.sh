#!/bin/sh
# Test:
#   Cli tool: list hooks for all types of hook sources

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

url1="ssh://git@github.com/test/repo1.git"
location1=$("$GITHOOKS_EXE_GIT_HOOKS" shared location "$url1") || exit 1

url2="https://github.com/test/repo2.git"
location2=$("$GITHOOKS_EXE_GIT_HOOKS" shared location "$url2") || exit 1

url3="ftp://github.com/test/repo3.git"
location3=$("$GITHOOKS_EXE_GIT_HOOKS" shared location "$url3") || exit 1

mkdir -p "$location1"/pre-commit &&
    cd "$location1" &&
    git init &&
    git remote add origin "$url1" &&
    echo 'echo "Hello"' >pre-commit/shared-pre1 &&
    echo 'echo "Hello"' >commit-msg

mkdir -p "$location2"/pre-push &&
    cd "$location2" &&
    git init &&
    git remote add origin "$url2" &&
    echo 'echo "Hello"' >post-commit &&
    echo 'echo "Hello"' >pre-push/shared-pre2 ||
    exit 1

mkdir -p "$location3"/post-update &&
    cd "$location3" &&
    git init &&
    git remote add origin "$url3" &&
    echo 'echo "Hello"' >post-rewrite &&
    echo 'echo "Hello"' >post-update/shared-pre3 ||
    exit 1

mkdir -p /tmp/test055/.githooks/pre-commit &&
    mkdir -p /tmp/test055/.githooks/post-commit &&
    echo 'echo "Hello"' >/tmp/test055/.githooks/pre-commit/local-pre &&
    echo 'echo "Hello"' >/tmp/test055/.githooks/post-commit/local-post &&
    echo 'echo "Hello"' >/tmp/test055/.githooks/post-merge &&
    echo "urls: - $url2" >/tmp/test055/.githooks/.shared.yaml &&
    cd /tmp/test055 &&
    git init &&
    mkdir -p .git/hooks &&
    echo 'echo "Hello"' >.git/hooks/pre-commit.replaced.githook &&
    chmod +x .git/hooks/pre-commit.replaced.githook &&
    git config --local githooks.shared "$url3" ||
    exit 1

git config --global githooks.shared "$url1" || exit 1

if ! "$GITHOOKS_EXE_GIT_HOOKS" list pre-commit | grep -q "'replaced'"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list pre-commit | grep "shared-pre1" | grep -q "'shared:global'"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list pre-commit | grep "local-pre" | grep "'repo'"; then
    echo "! Unexpected cli list output (3)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list commit-msg | grep "'shared:global'" | grep -q "commit-msg"; then
    echo "! Unexpected cli list output (4)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list post-commit | grep "local-post" | grep -q "'repo'"; then
    echo "! Unexpected cli list output (6)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list post-commit | grep "'shared:repo'" | grep -q "post-commit"; then
    echo "! Unexpected cli list output (5)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list post-merge | grep "'repo'" | grep -q "post-merge"; then
    echo "! Unexpected cli list output (7)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list pre-push | grep "shared-pre2" | grep -q "'shared:repo'"; then
    echo "! Unexpected cli list output (8)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list post-update | grep "shared-pre3" | grep -q "'shared:local'"; then
    echo "! Unexpected cli list output (9)"
    exit 1
fi

if ! "$GITHOOKS_EXE_GIT_HOOKS" list post-rewrite | grep "'shared:local'" | grep -q "'post-rewrite'"; then
    echo "! Unexpected cli list output (10)"
    exit 1
fi
