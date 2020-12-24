#!/bin/sh
# Test:
#   Direct template execution: do not accept any new hooks

# Pseudo installation.
mkdir -p ~/.githooks/release &&
    cp -r /var/lib/githooks/githooks/bin ~/.githooks ||
    exit 1
mkdir -p /tmp/test26 && cd /tmp/test26 || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo 'echo "First execution" >> /tmp/test026.out' >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=N ~/.githooks/bin/runner "$(pwd)"/.git/hooks/pre-commit

if grep -q "First execution" /tmp/test026.out; then
    echo "! Expected to refuse executing the hook"
    exit 1
fi
