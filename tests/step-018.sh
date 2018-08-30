#!/bin/sh
# Test:
#   Direct template execution: fail on shared hooks

mkdir -p /tmp/shared/hooks-018.git/pre-commit &&
    echo 'exit 1' >/tmp/shared/hooks-018.git/pre-commit/fail &&
    cd /tmp/shared/hooks-018.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p /tmp/test18 && cd /tmp/test18 || exit 1
git init || exit 1

mkdir -p .githooks &&
    echo '/tmp/shared/hooks-018.git' >.githooks/.shared &&
    HOOK_NAME='.githooks.shared.trigger' \
        sh /var/lib/githooks/base-template.sh ||
    exit 1

HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    sh /var/lib/githooks/base-template.sh

if [ $? -ne 1 ]; then
    echo "! Expected to fail on shared hook execution"
    exit 1
fi
