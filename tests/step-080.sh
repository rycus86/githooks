#!/bin/sh
# Test:
#   Cli tool: add/update README

if ! "$GITHOOKS_TEST_BIN_DIR/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/not/a/git/repo && cd /tmp/not/a/git/repo || exit 1

if "$GITHOOKS_INSTALL_BIN_DIR/cli" readme add; then
    echo "! Expected to fail"
    exit 1
fi

mkdir -p /tmp/test080 && cd /tmp/test080 && git init || exit 1

"$GITHOOKS_INSTALL_BIN_DIR/cli" readme update &&
    [ -f .githooks/README.md ] ||
    exit 1

if "$GITHOOKS_INSTALL_BIN_DIR/cli" readme add; then
    echo "! Expected to fail"
    exit 1
fi
