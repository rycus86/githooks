#!/bin/sh
# Test:
#   Cli tool: manage trust settings

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test081 && cd /tmp/test081 && git init || exit 1

git hooks trust &&
    [ -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "Y" ] ||
    exit 1

git hooks trust revoke &&
    [ -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "N" ] ||
    exit 2

git hooks trust delete &&
    [ ! -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "N" ] ||
    exit 3

git hooks trust forget &&
    [ -z "$(git config --local --get githooks.trust.all)" ] &&
    git hooks trust forget ||
    exit 4

git hooks trust invalid && exit 5

# Check the Git alias
git hooks trust &&
    git hooks trust revoke &&
    git hooks trust delete &&
    git hooks trust forget ||
    exit 6
