#!/bin/sh
# Test:
#   Cli tool: manage trusted repository configuration

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test093 && cd /tmp/test093 || exit 2

! "$GITHOOKS_EXE_GIT_HOOKS" config trusted --accept || exit 3

git init || exit 4

! "$GITHOOKS_EXE_GIT_HOOKS" config trusted || exit 5

"$GITHOOKS_EXE_GIT_HOOKS" config trusted --accept &&
    "$GITHOOKS_EXE_GIT_HOOKS" config trusted --accept | grep -q 'trusts all hooks' || exit 6

"$GITHOOKS_EXE_GIT_HOOKS" config trusted --deny &&
    "$GITHOOKS_EXE_GIT_HOOKS" config trusted --print | grep -q 'does not trust hooks' || exit 7

"$GITHOOKS_EXE_GIT_HOOKS" config trusted --reset &&
    "$GITHOOKS_EXE_GIT_HOOKS" config trusted --print | grep -q 'is not set' || exit 8
