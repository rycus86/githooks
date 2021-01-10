#!/bin/sh
# Test:
#   Run the cli tool in a directory that is not a Git repository

mkdir /tmp/not-a-git-repo && cd /tmp/not-a-git-repo || exit 1

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

if "$GITHOOKS_INSTALL_BIN_DIR/cli" list; then
    echo "! Expected to fail"
    exit 1
fi

if "$GITHOOKS_INSTALL_BIN_DIR/cli" trust; then
    echo "! Expected to fail"
    exit 1
fi

if "$GITHOOKS_INSTALL_BIN_DIR/cli" disable; then
    echo "! Expected to fail"
    exit 1
fi
