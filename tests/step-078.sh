#!/bin/sh
# Test:
#   Cli tool: enable/disable auto updates

if ! "$GITHOOKS_BIN_DIR/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

git config --global --unset githooks.autoUpdateEnabled &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" update --enable &&
    [ "$(git config --get githooks.autoUpdateEnabled)" = "true" ] ||
    exit 1

git config --global --unset githooks.autoUpdateEnabled &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" update --disable &&
    [ "$(git config --get githooks.autoUpdateEnabled)" = "false" ] ||
    exit 1
