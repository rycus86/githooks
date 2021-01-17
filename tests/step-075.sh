#!/bin/sh
# Test:
#   Uninstall: start directory options for existing repos

mkdir -p /tmp/test074/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test074/.githooks/pre-commit/testing &&
    cd /tmp/test074 &&
    git init ||
    exit 1

echo 'y
y
/tmp
' | "$GITHOOKS_TEST_BIN_DIR/installer" --stdin || exit 1

echo 'y

' | "$GITHOOKS_TEST_BIN_DIR/uninstaller" --stdin || exit 2

echo 'y
/not/found
' | "$GITHOOKS_TEST_BIN_DIR/uninstaller" --stdin

# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
    echo "! Uninstall unexpectedly finished"
    exit 1
fi
