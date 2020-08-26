#!/bin/sh
# Test:
#   Direct template execution: break on errors

mkdir -p /tmp/test13 && cd /tmp/test13 || exit 1
git init || exit 1

mkdir -p .githooks &&
    echo 'exit 1' >.githooks/pre-commit &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh /var/lib/githooks/base-template-wrapper.sh

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

rm .githooks/pre-commit &&
    mkdir .githooks/pre-commit &&
    echo 'exit 1' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh /var/lib/githooks/base-template-wrapper.sh

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

echo 'exit 0' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh /var/lib/githooks/base-template-wrapper.sh ||
    exit 1
