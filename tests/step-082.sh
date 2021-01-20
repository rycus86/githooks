#!/bin/sh
# Test:
#   Cli tool: manage global shared hook repositories

if ! "$GH_TEST_BIN/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p "$GH_TEST_TMP/shared/first-shared.git/.githooks/pre-commit" &&
    mkdir -p "$GH_TEST_TMP/shared/second-shared.git/.githooks/pre-commit" &&
    mkdir -p "$GH_TEST_TMP/shared/third-shared.git/.githooks/pre-commit" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/shared/first-shared.git/.githooks/pre-commit/sample-one" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/shared/second-shared.git/.githooks/pre-commit/sample-two" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/shared/third-shared.git/.githooks/pre-commit/sample-three" &&
    (cd "$GH_TEST_TMP/shared/first-shared.git" && git init && git add . && git commit -m 'Testing') &&
    (cd "$GH_TEST_TMP/shared/second-shared.git" && git init && git add . && git commit -m 'Testing') &&
    (cd "$GH_TEST_TMP/shared/third-shared.git" && git init && git add . && git commit -m 'Testing') ||
    exit 1

mkdir -p "$GH_TEST_TMP/test082" && cd "$GH_TEST_TMP/test082" && git init || exit 1

testShared() {

    url1="file://$GH_TEST_TMP/shared/first-shared.git"
    location1=$("$GITHOOKS_INSTALL_BIN_DIR/cli" shared location "$url1") || exit 1

    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared add --global "$url1" || exit 1
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared list | grep "first-shared" | grep "pending" || exit 2
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared pull || exit 3
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared list | grep "first-shared" | grep "active" || exit 4
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared add --global file://"$GH_TEST_TMP/shared/second-shared.git" || exit 5
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared add --global file://"$GH_TEST_TMP/shared/third-shared.git" || exit 6
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared list --global | grep "second-shared" | grep "pending" || exit 7
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared list --all | grep "third-shared" | grep "pending" || exit 8

    (cd "$location1" &&
        git remote rm origin &&
        git remote add origin /some/other/url.git) || exit 9
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared list | grep "first-shared" | grep "invalid" || exit 10
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared remove --global file://"$GH_TEST_TMP/shared/first-shared.git" || exit 11
    ! "$GITHOOKS_INSTALL_BIN_DIR/cli" shared list | grep "first-shared" || exit 12
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared remove --global file://"$GH_TEST_TMP/shared/second-shared.git" || exit 13
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared remove --global file://"$GH_TEST_TMP/shared/third-shared.git" || exit 14
    [ -z "$(git config --global --get-all githooks.shared)" ] || exit 15
}

testShared

"$GITHOOKS_INSTALL_BIN_DIR/cli" shared clear --all &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" shared purge ||
    exit 16

testShared
