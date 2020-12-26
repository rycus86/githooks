#!/bin/sh
# Test:
#   Run the cli tool trying to list a not yet trusted repo

if ! /var/lib/githooks/githooks/bin/installer --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test073/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test073/.githooks/pre-commit/testing &&
    touch /tmp/test073/.githooks/trust-all &&
    cd /tmp/test073 &&
    git init ||
    exit 1

if git hooks list pre-commit | grep -i 'trusted'; then
    echo "! Unexpected list result"
    exit 1
fi
