#!/bin/sh
# Test:
#   Automatic update checks are already enabled

echo 'y
' | /var/lib/githooks/githooks/bin/installer --stdin || exit 1

if [ "$(git config --global --get githooks.autoupdate.enabled)" != "true" ]; then
    echo "! Automatic update checks are not enabled"
    exit 1
fi

OUTPUT=$(/var/lib/githooks/githooks/bin/installer --stdin 2>&1)

# shellcheck disable=SC2181
if [ $? -ne 0 ] || echo "$OUTPUT" | grep -qi "automatic update checks"; then
    echo "! Automatic updates should have been set up already:"
    echo "$OUTPUT"
    exit 1
fi
