#!/bin/sh
# Test:
#   Run the cli tool for a hook that can't be found

mkdir /tmp/test070 && cd /tmp/test070 && git init || exit 1

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

if sh /var/lib/githooks/cli.sh enable not-found; then
    echo "! Unexpected enable result"
    exit 1
fi

if sh /var/lib/githooks/cli.sh disable not-found; then
    echo "! Unexpected disable result"
    exit 1
fi

if sh /var/lib/githooks/cli.sh accept not-found; then
    echo "! Unexpected accept result"
    exit 1
fi
