#!/bin/sh
# Test:
#   Run the cli tool in a directory that is not a Git repository

mkdir /tmp/not-a-git-repo && cd /tmp/not-a-git-repo || exit 1

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

if "$GITHOOKS_EXE_GIT_HOOKS" list; then
    echo "! Expected to fail"
    exit 1
fi

if "$GITHOOKS_EXE_GIT_HOOKS" trust; then
    echo "! Expected to fail"
    exit 1
fi

if "$GITHOOKS_EXE_GIT_HOOKS" disable; then
    echo "! Expected to fail"
    exit 1
fi
