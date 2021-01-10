#!/bin/sh
# Test:
#   Cli tool: list current hooks per type

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

mkdir -p /tmp/test054/.githooks/pre-commit &&
    mkdir -p /tmp/test054/.githooks/post-commit &&
    echo 'echo "Hello"' >/tmp/test054/.githooks/pre-commit/pre-example &&
    echo 'echo "Hello"' >/tmp/test054/.githooks/post-commit/post-example &&
    cd /tmp/test054 &&
    git init ||
    exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list pre-commit | grep "pre-example"; then
    echo "! Unexpected cli list output"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list post-commit | grep "post-example"; then
    echo "! Unexpected cli list output"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list post-commit | grep -v "pre-example"; then
    echo "! Unexpected cli list output"
    exit 1
fi
