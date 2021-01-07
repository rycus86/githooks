#!/bin/sh
# Test:
#   Run the cli tool for a hook that can't be found

mkdir /tmp/test070 && cd /tmp/test070 && git init || exit 1

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

# @todo maybe add a test for "git hooks ignore".
# Not sure yet if it makes sense. Its more work...
# Checking if any added pattern has an effect.

if "$GITHOOKS_EXE_GIT_HOOKS" trust hooks --path not-found; then
    echo "! Unexpected accept result"
    exit 1
fi

if "$GITHOOKS_EXE_GIT_HOOKS" trust hooks --pattern not-found; then
    echo "! Unexpected accept result"
    exit 1
fi
