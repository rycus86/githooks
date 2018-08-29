#!/bin/sh
# Test:
#   Cli tool: list shows files in trusted repos

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test060/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test060/.githooks/pre-commit/first &&
    echo 'echo "Hello"' >/tmp/test060/.githooks/pre-commit/second &&
    touch /tmp/test060/.githooks/trust-all &&
    cd /tmp/test060 &&
    git init &&
    git config --local githooks.trust.all Y ||
    exit 1

if ! sh /var/lib/githooks/cli.sh list | grep "first" | grep -q "trusted"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep "second" | grep -q "trusted"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! git hooks list; then
    echo "! The Git alias integration failed"
    exit 1
fi
