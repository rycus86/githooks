#!/bin/sh
# Test:
#   Cli tool: manage update time configuration

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Update time configuration

! git hooks config unknown update-time || exit 2

git hooks config print update-time | grep 'never' || exit 3

git config --global githooks.autoupdate.lastrun 123 &&
    git hooks config print update-time | grep -v 'never' || exit 4

git hooks config reset update-time &&
    git hooks config print update-time | grep 'never' || exit 5
