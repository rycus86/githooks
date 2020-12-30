#!/bin/sh
# Test:
#   Cli tool: manage trust settings

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test081 && cd /tmp/test081 && git init || exit 1

"$GITHOOKS_EXE_GIT_HOOKS" trust &&
    [ -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "true" ] ||
    exit 1

"$GITHOOKS_EXE_GIT_HOOKS" trust revoke &&
    [ -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "false" ] ||
    exit 2

"$GITHOOKS_EXE_GIT_HOOKS" trust delete &&
    [ ! -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "false" ] ||
    exit 3

"$GITHOOKS_EXE_GIT_HOOKS" trust forget &&
    [ -z "$(git config --local --get githooks.trust.all)" ] &&
    "$GITHOOKS_EXE_GIT_HOOKS" trust forget ||
    exit 4

"$GITHOOKS_EXE_GIT_HOOKS" trust invalid && exit 5

exit 0
