#!/bin/sh
# Test:
#   Cli tool: run an installation

mkdir -p "$GH_TEST_TMP/test094/a" "$GH_TEST_TMP/test094/b" "$GH_TEST_TMP/test094/c" &&
    cd "$GH_TEST_TMP/test094/a" && git init &&
    cd "$GH_TEST_TMP/test094/b" && git init ||
    exit 1

"$GH_TEST_BIN/installer" || exit 1

git config --global githooks.previousSearchDir "$GH_TEST_TMP"

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" install --global; then
    echo "! Failed to run the global installation"
    exit 1
fi

if ! grep 'rycus86/githooks' "$GH_TEST_TMP/test094/a/.git/hooks/pre-commit"; then
    echo "! Global installation was unsuccessful"
    exit 1
fi

if (cd "$GH_TEST_TMP/test094/c" && "$GITHOOKS_INSTALL_BIN_DIR/cli" install); then
    echo "! Install expected to fail outside a repository"
    exit 1
fi

# Reset to trigger a global update
if ! (cd ~/.githooks/release && git status && git reset --hard HEAD^); then
    echo "! Could not reset master to trigger update."
    exit 1
fi

CURRENT="$(cd ~/.githooks/release && git rev-parse HEAD)"
if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" install --global; then
    echo "! Expected global installation to succeed"
    exit 1
fi
AFTER="$(cd ~/.githooks/release && git rev-parse HEAD)"
if [ "$CURRENT" = "$AFTER" ]; then
    echo "! Release clone was not updated, but it should have!"
    exit 1
fi
