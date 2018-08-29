#!/bin/sh
# Test:
#   Cli tool: enable a hook

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test057/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test057/.githooks/pre-commit/first &&
    echo 'echo "Hello"' >/tmp/test057/.githooks/pre-commit/second &&
    cd /tmp/test057 &&
    git init ||
    exit 1

if ! sh /var/lib/githooks/cli.sh disable; then
    echo "! Failed to disable all hooks"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep "first" | grep -q "disabled"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep "second" | grep -q "disabled"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh enable .githooks/pre-commit/first; then
    echo "! Failed to enable a hook by path"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep "first" | grep -qv "disabled"; then
    echo "! Unexpected cli list output (3)"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep "second" | grep -q "disabled"; then
    echo "! Unexpected cli list output (4)"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh enable pre-commit second; then
    echo
    echo
    echo "! Failed to enable a hook by type and name"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep "first" | grep -qv "disabled"; then
    echo "! Unexpected cli list output (5)"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep "second" | grep -qv "disabled"; then
    echo "! Unexpected cli list output (6)"
    exit 1
fi

if ! git hooks enable || ! git hooks list; then
    echo "! The Git alias integration failed"
    exit 1
fi
