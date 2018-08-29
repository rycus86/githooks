#!/bin/sh
# Test:
#   Run the cli tool trying to accept a disabled hook

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test071/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test071/.githooks/pre-commit/testing &&
    cd /tmp/test071 &&
    git init ||
    exit 1

if ! sh /var/lib/githooks/cli.sh disable testing; then
    echo "! Failed to disable the hook"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep 'testing' | grep 'disabled'; then
    echo "! Unexpected hook state (1)"
    exit 1
fi

if sh /var/lib/githooks/cli.sh accept testing | grep -i 'accepted'; then
    echo "! Unexpected accept result"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep 'testing' | grep 'disabled'; then
    echo "! Unexpected hook state (2)"
    exit 1
fi
