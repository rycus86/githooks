#!/bin/sh
# Test:
#   Run the cli tool trying to list hooks of invalid type

if ! "$GH_TEST_BIN/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p "$GH_TEST_TMP/test072/.githooks/pre-commit" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/test072/.githooks/pre-commit/testing" &&
    cd "$GH_TEST_TMP/test072" &&
    git init ||
    exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list pre-commit; then
    echo "! Failed to execute a valid list"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list invalid-type 2>&1 | grep -q 'not managed by'; then
    echo "! Unexpected list result"
    exit 1
fi
