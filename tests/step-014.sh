#!/bin/sh
# Test:
#   Direct template execution: disable running custom hooks

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/test14 && cd /tmp/test14 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo 'exit 1' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh ~/.githooks/release/base-template-wrapper.sh

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

GITHOOKS_DISABLE=1 HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    sh ~/.githooks/release/base-template-wrapper.sh ||
    exit 1
