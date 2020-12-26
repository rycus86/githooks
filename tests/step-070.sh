#!/bin/sh
# Test:
#   Run the cli tool for a hook that can't be found

mkdir /tmp/test070 && cd /tmp/test070 && git init || exit 1

if ! /var/lib/githooks/githooks/bin/installer --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

if git hooks enable not-found; then
    echo "! Unexpected enable result"
    exit 1
fi

if git hooks disable not-found; then
    echo "! Unexpected disable result"
    exit 1
fi

if git hooks accept not-found; then
    echo "! Unexpected accept result"
    exit 1
fi
