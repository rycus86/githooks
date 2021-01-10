#!/bin/sh
# Test:
#   Cli tool: manage disable configuration

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test090 && cd /tmp/test090 || exit 2

! "$GITHOOKS_EXE_GIT_HOOKS" config disable --set || exit 3 # not a Git repository

git init || exit 4

! "$GITHOOKS_EXE_GIT_HOOKS" config disable || exit 5

"$GITHOOKS_EXE_GIT_HOOKS" config disable --set &&
    "$GITHOOKS_EXE_GIT_HOOKS" config disable --print | grep -q 'is disabled' || exit 6
"$GITHOOKS_EXE_GIT_HOOKS" config disable --reset &&
    "$GITHOOKS_EXE_GIT_HOOKS" config disable --print | grep -q 'is not disabled' || exit 7
