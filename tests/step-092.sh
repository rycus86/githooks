#!/bin/sh
# Test:
#   Cli tool: manage global shared hook repository configuration

if ! "$GH_TEST_BIN/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config shared || exit 1
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --add || exit 1
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --local --add "asd" || exit 1

mkdir -p "$GH_TEST_TMP/test092" && cd "$GH_TEST_TMP/test092" && git init || exit 2

! "$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --local --add "" || exit 3
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --global --local --add "a" "b" || exit 3
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --local --print --add "a" "b" || exit 3

"$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --add "file://$GH_TEST_TMP/test/repo1.git" "file://$GH_TEST_TMP/test/repo2.git" || exit 4
"$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --global --print | grep -q 'test/repo1' || exit 5
"$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --global --print | grep -q 'test/repo2' || exit 6
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --local --print | grep -q 'test/repo' || exit 7

"$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --local --add "file://$GH_TEST_TMP/test/repo3.git" || exit 8
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --global --print | grep -q 'test/repo3' || exit 9
"$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --local --print | grep -q 'test/repo3' || exit 10
"$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --print | grep -q 'test/repo1' || exit 11
"$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --print | grep -q 'test/repo2' || exit 12
"$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --print | grep -q 'test/repo3' || exit 13

"$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --reset &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config shared --print | grep -q -i 'none' || exit 14
