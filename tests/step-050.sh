#!/bin/sh
# Test:
#   Run a default install and verify the cli helper is installed

"$GITHOOKS_BIN_DIR/installer" || exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" --version; then
    echo "! The command line helper tool is not available"
    exit 1
fi
