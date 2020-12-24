#!/bin/sh
# Test:
#   Direct template execution: do not run any hooks in the current repo

# Pseudo installation.
mkdir -p ~/.githooks/release &&
    cp -r /var/lib/githooks/githooks/bin ~/.githooks ||
    exit 1
mkdir -p /tmp/test47 && cd /tmp/test47 || exit 1
git init || exit 1

cat ~/.githooks/release/base-template-wrapper.sh

mkdir -p .githooks/pre-commit &&
    git config githooks.disable Y &&
    echo 'echo "Accepted hook" > /tmp/test47.out' >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=Y \
        ~/.githooks/bin/runner "$(pwd)"/.git/hooks/pre-commit

if [ -f /tmp/test47.out ]; then
    echo "! Hook was unexpectedly run"
    exit 1
fi

echo 'echo "Changed hook" > /tmp/test47.out' >.githooks/pre-commit/test &&
    git config --unset githooks.disable &&
    ACCEPT_CHANGES=Y \
        ~/.githooks/bin/runner "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "Changed hook" /tmp/test47.out; then
    echo "! Changed hook was not run"
    exit 1
fi
