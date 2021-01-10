#!/bin/sh
# Test:
#   Cli tool: manage ignore files

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test085 && cd /tmp/test085 || exit 1
git init || exit 2

"$GITHOOKS_INSTALL_BIN_DIR/cli" ignore add --repository --pattern "pre-commit/test-root" &&
    grep -q 'pre-commit/test-root' ".githooks/.ignore.yaml" || exit 6

"$GITHOOKS_INSTALL_BIN_DIR/cli" ignore add --repository --path "pre-commit/test-second" &&
    grep -q "test-root" ".githooks/.ignore.yaml" &&
    grep -q "test-second" ".githooks/.ignore.yaml" || exit 7

"$GITHOOKS_INSTALL_BIN_DIR/cli" ignore add --repository --hook-name "pre-commit" --path "test-pc" &&
    grep -q "test-pc" ".githooks/pre-commit/.ignore.yaml" || exit 7

mkdir -p ".githooks/post-commit/.ignore.yaml" &&
    ! "$GITHOOKS_INSTALL_BIN_DIR/cli" ignore add --repository --hook-name "post-commit" --pattern "test-fail" &&
    [ ! -f ".githooks/post-commit/.ignore.yaml" ] || exit 8
