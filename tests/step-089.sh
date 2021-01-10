#!/bin/sh
# Test:
#   Cli tool: manage update state configuration

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

! "$GITHOOKS_EXE_GIT_HOOKS" config update || exit 2

"$GITHOOKS_EXE_GIT_HOOKS" config update --disable &&
    "$GITHOOKS_EXE_GIT_HOOKS" config update --print | grep -q 'disabled' || exit 3

"$GITHOOKS_EXE_GIT_HOOKS" config update --enable &&
    "$GITHOOKS_EXE_GIT_HOOKS" config update --print | grep -q 'enabled' || exit 4

"$GITHOOKS_EXE_GIT_HOOKS" config update --disable &&
    "$GITHOOKS_EXE_GIT_HOOKS" config update --print | grep -q 'disabled' || exit 5
