#!/bin/sh
# Test:
#   Cli tool: manage trusted repository configuration

if ! "$GITHOOKS_BIN_DIR/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test093 && cd /tmp/test093 || exit 2

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --accept || exit 3

git init || exit 4

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted || exit 5

"$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --accept &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --accept | grep -q 'trusts all hooks' || exit 6

"$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --deny &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --print | grep -q 'does not trust hooks' || exit 7

"$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --reset &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --print | grep -q 'is not set' || exit 8
