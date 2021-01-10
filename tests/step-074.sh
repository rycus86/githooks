#!/bin/sh
# Test:
#   Cli tool: list pending changes

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test074/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test074/.githooks/pre-commit/testing &&
    cd /tmp/test074 &&
    git init ||
    exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list pre-commit | grep 'testing' | grep "'active'" | grep -q "'untrusted'"; then
    echo "! Unexpected list result (1)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" trust hooks --path "pre-commit/testing"; then
    echo "! Failed to accept the hook"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list pre-commit | grep 'testing' | grep "'active'" | grep -q "'trusted'"; then
    echo "! Unexpected list result (2)"
    exit 1
fi

echo 'echo "Changed"' >/tmp/test074/.githooks/pre-commit/testing || exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list pre-commit | grep 'testing' | grep "'active'" | grep -q "'untrusted'"; then
    echo "! Unexpected list result (2)"
    exit 1
fi
