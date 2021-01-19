#!/bin/sh
# Test:
#   Cli tool: list shows files in trusted repos

"$GH_TEST_BIN/installer" || exit 1

mkdir -p "$GH_TEST_TMP/test060/.githooks/pre-commit" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/test060/.githooks/pre-commit/first" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/test060/.githooks/pre-commit/second" &&
    touch "$GH_TEST_TMP/test060/.githooks/trust-all" &&
    cd "$GH_TEST_TMP/test060" &&
    git init &&
    git config --local githooks.trustAll true ||
    exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "first" | grep -q "'trusted'"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "second" | grep -q "'trusted'"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi
