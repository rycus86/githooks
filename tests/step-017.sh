#!/bin/sh
# Test:
#   Direct template execution: execute a previously saved hook

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/test017 && cd /tmp/test017 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo 'echo "Direct execution" >> /tmp/test017.out' >.githooks/pre-commit/test &&
    echo 'echo "Previous hook" >> /tmp/test017.out' >.git/hooks/pre-commit.replaced.githook &&
    chmod +x .git/hooks/pre-commit.replaced.githook &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh ~/.githooks/release/base-template-wrapper.sh ||
    exit 1

if ! grep -q 'Direct execution' /tmp/test017.out; then
    echo "! Direct execution didn't happen"
    exit 1
fi

if ! grep -q 'Previous hook' /tmp/test017.out; then
    echo "! Previous hook was not executed"
    exit 1
fi
