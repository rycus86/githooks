#!/bin/sh
# Test:
#   Cli tool: manage previous search directory configuration

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

! "$GITHOOKS_EXE_GIT_HOOKS" config search-dir || exit 2
! "$GITHOOKS_EXE_GIT_HOOKS" config search-dir --set || exit 3
! "$GITHOOKS_EXE_GIT_HOOKS" config search-dir --set a b c || exit 4

"$GITHOOKS_EXE_GIT_HOOKS" config search-dir --set /prev/search/dir || exit 5
"$GITHOOKS_EXE_GIT_HOOKS" config search-dir --print | grep -q '/prev/search/dir' || exit 6

"$GITHOOKS_EXE_GIT_HOOKS" config search-dir --reset
"$GITHOOKS_EXE_GIT_HOOKS" config search-dir --print | grep -q -i 'previous search directory is not set' || exit 7
