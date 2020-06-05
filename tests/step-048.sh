#!/bin/sh
# Test:
#   Direct template execution: do not run any hooks in any repos

git config --global githooks.disable true || exit 1

mkdir -p /tmp/test48 && cd /tmp/test48 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo 'echo "Accepted hook" > /tmp/test48.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    ACCEPT_CHANGES=Y \
        sh /var/lib/githooks/base-template.sh

if [ -f /tmp/test48.out ]; then
    echo "! Hook was unexpectedly run"
    exit 1
fi

git config --global --unset githooks.disable || exit 1

echo 'echo "Changed hook" > /tmp/test48.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    ACCEPT_CHANGES=Y \
        sh /var/lib/githooks/base-template.sh

if ! grep -q "Changed hook" /tmp/test48.out; then
    echo "! Changed hook was not run"
    exit 1
fi
