#!/bin/sh
# Test:
#   Direct template execution: disable running custom hooks

# Pseudo installation.
mkdir -p ~/.githooks/release &&
    cp -r /var/lib/githooks/githooks/bin ~/.githooks ||
    exit 1
mkdir -p /tmp/test14 && cd /tmp/test14 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo 'exit 1' >.githooks/pre-commit/test &&
    ~/.githooks/bin/runner "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

GITHOOKS_DISABLE=1 ~/.githooks/bin/runner "$(pwd)"/.git/hooks/pre-commit ||
    exit 1
