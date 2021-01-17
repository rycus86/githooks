#!/bin/sh
# Test:
#   Run an single-repo install in a directory that is not a Git repository

mkdir "$GH_TEST_TMP/not-a-git-repo" && cd "$GH_TEST_TMP/not-a-git-repo" || exit 1

if ! "$GH_TEST_BIN/installer"; then
    echo "! Expected to succeed"
    exit 1
fi

if "$GH_TEST_BIN/cli" install; then
    echo "! Install into current repo should have failed"
    exit 1
fi
