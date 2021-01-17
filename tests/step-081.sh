#!/bin/sh
# Test:
#   Cli tool: manage trust settings

if ! "$GITHOOKS_BIN_DIR/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test081 && cd /tmp/test081 && git init || exit 1

"$GITHOOKS_INSTALL_BIN_DIR/cli" trust &&
    [ -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trustAll)" = "true" ] ||
    exit 1

"$GITHOOKS_INSTALL_BIN_DIR/cli" trust revoke &&
    [ -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trustAll)" = "false" ] ||
    exit 2

"$GITHOOKS_INSTALL_BIN_DIR/cli" trust delete &&
    [ ! -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trustAll)" = "false" ] ||
    exit 3

"$GITHOOKS_INSTALL_BIN_DIR/cli" trust forget &&
    [ -z "$(git config --local --get githooks.trustAll)" ] &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" trust forget ||
    exit 4

"$GITHOOKS_INSTALL_BIN_DIR/cli" trust invalid && exit 5

exit 0
