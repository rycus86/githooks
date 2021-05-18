#!/bin/sh
# Test:
#   Cli tool: fix #157 wrong argument handling

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Update time configuration

OUTPUT=$(git hooks config 2>&1)

if ! echo "$OUTPUT" | grep 'Invalid configuration option'; then
    echo "$OUTPUT" >&2
    exit 2
fi
