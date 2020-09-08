#!/bin/sh
# Test:
#   Direct template execution: test pre-commit hooks

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/test11 && cd /tmp/test11 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo 'echo "Direct execution" > /tmp/test011.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh ~/.githooks/release/base-template-wrapper.sh ||
    exit 1

grep -q 'Direct execution' /tmp/test011.out
