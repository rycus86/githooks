#!/bin/sh
# Test:
#   Direct template execution: test a single pre-commit hook file

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/test12 && cd /tmp/test12 || exit 1
git init || exit 1

mkdir -p .githooks &&
    echo 'echo "Direct execution" > /tmp/test012.out' >.githooks/pre-commit &&
    ~/.githooks/release/base-template.sh "$(pwd)"/.git/hooks/pre-commit ||
    exit 1

grep -q 'Direct execution' /tmp/test012.out
