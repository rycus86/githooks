#!/bin/sh
# Test:
#   Cli tool: manage update time configuration

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

! "$GITHOOKS_EXE_GIT_HOOKS" config update-time || exit 2

"$GITHOOKS_EXE_GIT_HOOKS" config update-time --print | grep -q 'never' || exit 3

git config --global githooks.autoupdate.lastrun 123 &&
    "$GITHOOKS_EXE_GIT_HOOKS" config update-time --print | grep -q 'never' && exit 4

"$GITHOOKS_EXE_GIT_HOOKS" config update-time --reset &&
    "$GITHOOKS_EXE_GIT_HOOKS" config update-time --print | grep -q 'never' || exit 5
