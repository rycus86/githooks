#!/bin/sh
# Test:
#   Run an single-repo install in a directory that is not a Git repository

mkdir /tmp/not-a-git-repo && cd /tmp/not-a-git-repo || exit 1

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Expected to succeed"
    exit 1
fi

if "$GITHOOKS_BIN_DIR/cli" install; then
    echo "! Install into current repo should have failed"
    exit 1
fi
