#!/bin/sh
# Test:
#   Cli tool: list current hooks

"$GH_TEST_BIN/installer" || exit 1

mkdir -p "$GH_TEST_TMP/test053/.githooks/pre-commit" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/test053/.githooks/pre-commit/example" &&
    cd "$GH_TEST_TMP/test053" &&
    git init ||
    exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "example" | grep "'untrusted'" | grep "'active'"; then
    echo "! Unexpected cli list output"
    exit 1
fi

git commit -m 'Test'

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "example" | grep "'trusted'" | grep "'active'"; then
    echo "! Unexpected cli list output"
    exit 1
fi
