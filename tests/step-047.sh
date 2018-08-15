#!/bin/sh
# Test:
#   Direct template execution: do not run any hooks in the current repo

mkdir -p /tmp/test47 && cd /tmp/test47 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    git config githooks.disable Y &&
    echo 'echo "Accepted hook" > /tmp/test47.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    ACCEPT_CHANGES=Y \
        sh /var/lib/githooks/base-template.sh

if [ -f /tmp/test47.out ]; then
    echo "! Hook was unexpectedly run"
    exit 1
fi

echo 'echo "Changed hook" > /tmp/test47.out' >.githooks/pre-commit/test &&
    git config --unset githooks.disable &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    ACCEPT_CHANGES=Y \
        sh /var/lib/githooks/base-template.sh

if ! grep -q "Changed hook" /tmp/test47.out; then
    echo "! Changed hook was not run"
    exit 1
fi
