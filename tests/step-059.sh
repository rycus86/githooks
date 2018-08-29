#!/bin/sh
# Test:
#   Cli tool: list shows ignored files

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test059/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test059/.githooks/pre-commit/first &&
    echo 'echo "Hello"' >/tmp/test059/.githooks/pre-commit/second &&
    echo 'first' >/tmp/test059/.githooks/.ignore &&
    echo 'second' >/tmp/test059/.githooks/pre-commit/.ignore &&
    cd /tmp/test059 &&
    git init ||
    exit 1

if ! sh /var/lib/githooks/cli.sh list | grep "first" | grep -q "ignored"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep "second" | grep -q "ignored"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! git hooks list; then
    echo "! The Git alias integration failed"
    exit 1
fi
