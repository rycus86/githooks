#!/bin/sh
# Test:
#   Run the cli tool for a hook that can't be found

mkdir "$GH_TEST_TMP/test070" && cd "$GH_TEST_TMP/test070" && git init || exit 1

if ! "$GH_TEST_BIN/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

# @todo maybe add a test for "git hooks ignore".
# Not sure yet if it makes sense. Its more work...
# Checking if any added pattern has an effect.

if "$GITHOOKS_INSTALL_BIN_DIR/cli" trust hooks --path not-found; then
    echo "! Unexpected accept result"
    exit 1
fi

if "$GITHOOKS_INSTALL_BIN_DIR/cli" trust hooks --pattern not-found; then
    echo "! Unexpected accept result"
    exit 1
fi
