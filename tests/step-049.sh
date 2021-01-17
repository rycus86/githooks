#!/bin/sh
# Test:
#   Do not reenable automatic update checks in non-interactive mode

git config --global githooks.autoUpdateEnabled false || exit 1
"$GITHOOKS_TEST_BIN_DIR/installer" --non-interactive || exit 1

if [ "$(git config --global --get githooks.autoUpdateEnabled)" != "false" ]; then
    echo "! Automatic update checks were unexpectedly enabled"
    exit 1
fi
