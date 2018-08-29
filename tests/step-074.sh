#!/bin/sh
# Test:
#   Cli tool: list pending changes

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test074/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test074/.githooks/pre-commit/testing &&
    cd /tmp/test074 &&
    git init ||
    exit 1

if ! sh /var/lib/githooks/cli.sh list pre-commit | grep 'pending / new'; then
    echo "! Unexpected list result (1)"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh accept pre-commit testing; then
    echo "! Failed to accept the hook"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list pre-commit | grep 'active'; then
    echo "! Unexpected list result (2)"
    exit 1
fi

echo 'echo "Changed"' >/tmp/test074/.githooks/pre-commit/testing || exit 1

if ! sh /var/lib/githooks/cli.sh list pre-commit | grep 'pending / changed'; then
    echo "! Unexpected list result (3)"
    exit 1
fi
