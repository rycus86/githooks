#!/bin/sh
# Test:
#   Cli tool: manage previous search directory configuration

if ! "$GITHOOKS_TEST_BIN_DIR/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config search-dir || exit 2
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config search-dir --set || exit 3
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config search-dir --set a b c || exit 4

"$GITHOOKS_INSTALL_BIN_DIR/cli" config search-dir --set /prev/search/dir || exit 5
"$GITHOOKS_INSTALL_BIN_DIR/cli" config search-dir --print | grep -q '/prev/search/dir' || exit 6

"$GITHOOKS_INSTALL_BIN_DIR/cli" config search-dir --reset
"$GITHOOKS_INSTALL_BIN_DIR/cli" config search-dir --print | grep -q -i 'previous search directory is not set' || exit 7
