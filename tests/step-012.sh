#!/bin/sh
# Test:
#   Direct template execution: test a single pre-commit hook file

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/test12 && cd /tmp/test12 || exit 1
git init || exit 1

mkdir -p .githooks &&
    echo 'echo "Direct execution" > /tmp/test012.out' >.githooks/pre-commit &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh ~/.githooks/release/base-template-wrapper.sh ||
    exit 1

grep -q 'Direct execution' /tmp/test012.out
