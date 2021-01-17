#!/bin/sh
# Test:
#   Cli tool: enable/disable hooks

if ! "$GITHOOKS_TEST_BIN_DIR/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test079 && cd /tmp/test079 && git init || exit 1

"$GITHOOKS_INSTALL_BIN_DIR/cli" disable &&
    [ "$(git config --get githooks.disable)" = "true" ] ||
    exit 1

"$GITHOOKS_INSTALL_BIN_DIR/cli" disable --reset &&
    [ "$(git config --get githooks.disable)" != "true" ] ||
    exit 1
