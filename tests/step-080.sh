#!/bin/sh
# Test:
#   Cli tool: add/update README

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/not/a/git/repo && cd /tmp/not/a/git/repo || exit 1

if "$GITHOOKS_EXE_GIT_HOOKS" readme add; then
    echo "! Expected to fail"
    exit 1
fi

mkdir -p /tmp/test080 && cd /tmp/test080 && git init || exit 1

"$GITHOOKS_EXE_GIT_HOOKS" readme update &&
    [ -f .githooks/README.md ] ||
    exit 1

if "$GITHOOKS_EXE_GIT_HOOKS" readme add; then
    echo "! Expected to fail"
    exit 1
fi
