#!/bin/sh
# Test:
#   Cli tool: shared hook repository management failures

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

"$GITHOOKS_EXE_GIT_HOOKS" unknown && exit 2
"$GITHOOKS_EXE_GIT_HOOKS" shared add && exit 4
"$GITHOOKS_EXE_GIT_HOOKS" shared remove && exit 5
"$GITHOOKS_EXE_GIT_HOOKS" shared add --shared /tmp/some/repo.git && exit 6
"$GITHOOKS_EXE_GIT_HOOKS" shared remove --shared /tmp/some/repo.git && exit 7
"$GITHOOKS_EXE_GIT_HOOKS" shared clear && exit 8
"$GITHOOKS_EXE_GIT_HOOKS" shared clear unknown && exit 9
"$GITHOOKS_EXE_GIT_HOOKS" shared list unknown && exit 10
if "$GITHOOKS_EXE_GIT_HOOKS" shared list --shared; then
    exit 11
fi
