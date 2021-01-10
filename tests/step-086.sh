#!/bin/sh
# Test:
#   Cli tool: list Githooks configuration

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test086 && cd /tmp/test086 || exit 3

! "$GITHOOKS_EXE_GIT_HOOKS" config list --local || exit 4 # not a Git repo

git init || exit 5

"$GITHOOKS_EXE_GIT_HOOKS" config update --enable || exit 7
"$GITHOOKS_EXE_GIT_HOOKS" config list | grep -q 'githooks.autoupdate.enabled' || exit 8
"$GITHOOKS_EXE_GIT_HOOKS" config list --global | grep -q 'githooks.autoupdate.enabled' || exit 9
! "$GITHOOKS_EXE_GIT_HOOKS" config list --local | grep -q 'githooks.autoupdate.enabled' || exit 10
