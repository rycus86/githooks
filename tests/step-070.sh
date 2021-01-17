#!/bin/sh
# Test:
#   Run the cli tool for a hook that can't be found

mkdir /tmp/test070 && cd /tmp/test070 && git init || exit 1

if ! "$GITHOOKS_TEST_BIN_DIR/installer"; then
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
