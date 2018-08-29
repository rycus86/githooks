#!/bin/sh
# Test:
#   Run the cli tool trying to list hooks of invalid type

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test072/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test072/.githooks/pre-commit/testing &&
    cd /tmp/test072 &&
    git init ||
    exit 1

if ! sh /var/lib/githooks/cli.sh list pre-commit; then
    echo "! Failed to execute a valid list"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list invalid-type | grep -i 'no active hooks'; then
    echo "! Unexpected list result"
    exit 1
fi
