#!/bin/sh
# Test:
#   Cli tool: enable/disable hooks

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test079 && cd /tmp/test079 && git init || exit 1

git hooks disable --all &&
    [ "$(git config --get githooks.disable)" = "true" ] ||
    exit 1

git hooks disable --reset &&
    [ "$(git config --get githooks.disable)" != "true" ] ||
    exit 1

# Check the Git alias
git hooks disable -a &&
    [ "$(git config --get githooks.disable)" = "true" ] ||
    exit 1

git hooks disable -r &&
    [ "$(git config --get githooks.disable)" != "true" ] ||
    exit 1
