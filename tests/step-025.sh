#!/bin/sh
# Test:
#   Direct template execution: break if the previously moved hook is failing

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/test25 && cd /tmp/test25 || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo 'echo "Direct execution" >> /tmp/test025.out' >.githooks/pre-commit/test &&
    echo 'exit 1' >.git/hooks/pre-commit.replaced.githook &&
    chmod +x .git/hooks/pre-commit.replaced.githook &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh ~/.githooks/release/base-template-wrapper.sh

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

echo '*.replaced.githook' >.githooks/.ignore &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh ~/.githooks/release/base-template-wrapper.sh ||
    exit 1
