#!/bin/sh
# Test:
#   Direct template execution: do not run disabled hooks

mkdir -p /tmp/test27 && cd /tmp/test27 || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo 'echo "First execution" >> /tmp/test027.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks ACCEPT_CHANGES=D \
        sh /var/lib/githooks/base-template.sh

if grep -q "First execution" /tmp/test027.out; then
    echo "! Expected to refuse executing the hook the first time"
    exit 1
fi

if ! grep -q "disabled> $(pwd)/.githooks/pre-commit/test" .git/.githooks.checksum; then
    echo "! Expected to disable the hook"
    exit 1
fi

echo 'echo "Second execution" >> /tmp/test027.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks ACCEPT_CHANGES=Y \
        sh /var/lib/githooks/base-template.sh

if grep -q "Second execution" /tmp/test027.out; then
    echo "! Expected to refuse executing the hook the second time"
    exit 1
fi
