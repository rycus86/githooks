#!/bin/sh
# Test:
#   Cli tool: manage trusted repository configuration

if ! "$GH_TEST_BIN/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p "$GH_TEST_TMP/test093" && cd "$GH_TEST_TMP/test093" || exit 2

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --accept || exit 3

git init || exit 4

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted || exit 5

"$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --accept &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --accept | grep -q 'trusts all hooks' || exit 6

"$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --deny &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --print | grep -q 'does not trust hooks' || exit 7

"$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --reset &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --print | grep -q 'is not set' || exit 8
