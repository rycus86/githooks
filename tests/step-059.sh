#!/bin/sh
# Test:
#   Cli tool: list shows ignored files

"$GH_TEST_BIN/installer" || exit 1

mkdir -p "$GH_TEST_TMP/test059/.githooks/pre-commit" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/test059/.githooks/pre-commit/first" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/test059/.githooks/pre-commit/second" &&
    echo 'patterns: - pre-commit/first' >"$GH_TEST_TMP/test059/.githooks/.ignore.yaml" &&
    echo 'patterns: - pre-commit/second' >"$GH_TEST_TMP/test059/.githooks/pre-commit/.ignore.yaml" &&
    cd "$GH_TEST_TMP/test059" &&
    git init ||
    exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "first" | grep -q "'ignored'"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "second" | grep -q "'ignored'"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi
