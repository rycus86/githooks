#!/bin/sh
# Test:
#   Cli tool: manage disable configuration

if ! "$GH_TEST_BIN/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p "$GH_TEST_TMP/test090" && cd "$GH_TEST_TMP/test090" || exit 2

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config disable --set || exit 3 # not a Git repository

git init || exit 4

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config disable || exit 5

"$GITHOOKS_INSTALL_BIN_DIR/cli" config disable --set &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config disable --print | grep -q 'is disabled' || exit 6
"$GITHOOKS_INSTALL_BIN_DIR/cli" config disable --reset &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config disable --print | grep -q 'is not disabled' || exit 7
