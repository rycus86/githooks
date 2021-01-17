#!/bin/sh
# Test:
#   Cli tool: manage update state configuration

if ! "$GITHOOKS_TEST_BIN_DIR/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config update || exit 2

"$GITHOOKS_INSTALL_BIN_DIR/cli" config update --disable &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config update --print | grep -q 'disabled' || exit 3

"$GITHOOKS_INSTALL_BIN_DIR/cli" config update --enable &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config update --print | grep -q 'enabled' || exit 4

"$GITHOOKS_INSTALL_BIN_DIR/cli" config update --disable &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config update --print | grep -q 'disabled' || exit 5
