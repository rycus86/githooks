#!/bin/sh
# Test:
#   Cli tool: enable a hook

"$GITHOOKS_BIN_DIR/installer" || exit 1

mkdir -p /tmp/test057/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test057/.githooks/pre-commit/first &&
    echo 'echo "Hello"' >/tmp/test057/.githooks/pre-commit/second &&
    cd /tmp/test057 &&
    git init ||
    exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" ignore add --pattern "**/*"; then
    echo "! Failed ignore hooks"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "first" | grep -q "'ignored'" ||
    ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "second" | grep -q "'ignored'"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" disable; then
    echo "! Failed to disable Githooks"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "first" | grep -q "'disabled'" ||
    ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "second" | grep -q "'disabled'"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" ignore add --pattern '!**/*'; then
    echo "! Failed to ignore hooks"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "first" | grep -q "'disabled'" ||
    ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "second" | grep -q "'disabled'"; then
    echo "! Unexpected cli list output (3)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" disable --reset; then
    echo "! Failed to reset disabling Githooks"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "first" | grep -q "'active'" ||
    ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "second" | grep -q "'active'"; then
    echo "! Unexpected cli list output (4)"
    "$GITHOOKS_INSTALL_BIN_DIR/cli" list
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" ignore remove --pattern "**/*"; then
    echo "! Failed to remove a pattern"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" ignore add --pattern "**/*"; then
    echo "! Failed to add a pattern back to the end of the list"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "first" | grep -q "'ignored'" ||
    ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "second" | grep -q "'ignored'"; then
    echo "! Unexpected cli list output (5)"
    exit 1
fi
