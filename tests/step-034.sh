#!/bin/sh
# Test:
#   Direct template execution: update a hook in a trusted repository

mkdir -p /tmp/test34 && cd /tmp/test34 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    touch .githooks/trust-all &&
    echo 'echo "Trusted hook" > /tmp/test34.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    TRUST_ALL_HOOKS=Y ACCEPT_CHANGES=N \
        sh /var/lib/githooks/base-template-wrapper.sh

if ! grep -q "Trusted hook" /tmp/test34.out; then
    echo "! Expected hook was not run"
    exit 1
fi

echo 'echo "Changed hook" > /tmp/test34.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    TRUST_ALL_HOOKS="" ACCEPT_CHANGES=N \
        sh /var/lib/githooks/base-template-wrapper.sh

if ! grep -q "Changed hook" /tmp/test34.out; then
    echo "! Changed hook was not run"
    exit 1
fi
