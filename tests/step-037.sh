#!/bin/sh
# Test:
#   Re-enabling automatic update checks

git config --global githooks.autoupdate.enabled false || exit 1
echo 'y
' | /var/lib/githooks/githooks/bin/installer --stdin || exit 1

if [ "$(git config --global --get githooks.autoupdate.enabled)" != "true" ]; then
    echo "! Automatic update checks are not enabled"
    exit 1
fi
