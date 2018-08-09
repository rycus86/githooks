#!/bin/sh
# Test:
#   Automatic update checks are already enabled

echo 'y
' | sh /var/lib/githooks/install.sh || exit 1

if [ "$(git config --global --get githooks.autoupdate.enabled)" != "Y" ]; then
    echo "! Automatic update checks are not enabled"
    exit 1
fi

OUTPUT=$(sh /var/lib/githooks/install.sh) || exit 1

if echo "$OUTPUT" | grep -qi "automatic update checks"; then
    echo "! Automatic updates should have been set up already"
    exit 1
fi
