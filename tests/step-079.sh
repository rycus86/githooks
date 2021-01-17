#!/bin/sh
# Test:
#   Cli tool: enable/disable hooks

if ! "$GH_TEST_BIN/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p "$GH_TEST_TMP/test079" && cd "$GH_TEST_TMP/test079" && git init || exit 1

"$GITHOOKS_INSTALL_BIN_DIR/cli" disable &&
    [ "$(git config --get githooks.disable)" = "true" ] ||
    exit 1

"$GITHOOKS_INSTALL_BIN_DIR/cli" disable --reset &&
    [ "$(git config --get githooks.disable)" != "true" ] ||
    exit 1
