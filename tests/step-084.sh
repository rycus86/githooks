#!/bin/sh
# Test:
#   Cli tool: shared hook repository management failures

if ! "$GH_TEST_BIN/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p "$GH_TEST_TMP/test084" && cd "$GH_TEST_TMP/test084" && git init || exit 1

"$GITHOOKS_INSTALL_BIN_DIR/cli" unknown && exit 2
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared add && exit 4
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared remove && exit 5
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared add --shared "$GH_TEST_TMP/some/repo.git" && exit 6
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared remove --shared "$GH_TEST_TMP/some/repo.git" 2>&1 | grep -q "does not exist" || exit
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared clear unknown && exit 9
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared list unknown && exit 10

exit 0
