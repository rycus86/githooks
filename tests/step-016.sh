#!/bin/sh
# Test:
#   Direct template execution: update shared hooks

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/shared/hooks-016-a.git/pre-commit &&
    echo 'echo "From shared hook A" >> /tmp/test-016.out' \
        >/tmp/shared/hooks-016-a.git/pre-commit/say-hello &&
    cd /tmp/shared/hooks-016-a.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p /tmp/shared/hooks-016-b.git/.githooks/pre-commit &&
    echo 'echo "From shared hook B" >> /tmp/test-016.out' \
        >/tmp/shared/hooks-016-b.git/.githooks/pre-commit/say-hello &&
    cd /tmp/shared/hooks-016-b.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p /tmp/test16 && cd /tmp/test16 || exit 1
git init || exit 1

mkdir -p .githooks &&
    git config --global githooks.shared '/tmp/shared/hooks-016-a.git' &&
    echo '/tmp/shared/hooks-016-b.git' >.githooks/.shared &&
    HOOK_NAME=post-merge HOOK_FOLDER=$(pwd)/.git/hooks \
        sh ~/.githooks/release/base-template-wrapper.sh unused ||
    exit 1

HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    sh ~/.githooks/release/base-template-wrapper.sh ||
    exit 1

if ! grep -q 'From shared hook A' /tmp/test-016.out; then
    echo "! The first shared hook was not run"
    exit 1
fi

if ! grep -q 'From shared hook B' /tmp/test-016.out; then
    echo "! The second shared hook was not run"
    exit 1
fi
