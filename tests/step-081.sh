#!/bin/sh
# Test:
#   Cli tool: manage trust settings

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test081 && cd /tmp/test081 && git init || exit 1

# Run with --local option
git hooks trust --local &&
    [ -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "Y" ] ||
    exit 1

git hooks trust --global &&
    [ "$(git config --global --get githooks.trust.all)" = "Y" ] ||
    exit 2

git hooks trust revoke &&
    [ -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "N" ] ||
    exit 3

git hooks trust delete &&
    [ ! -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "N" ] ||
    exit 4

git hooks trust forget --local &&
    [ -z "$(git config --local --get githooks.trust.all)" ] &&
    git hooks trust forget --local ||
    exit 5

git hooks trust forget --global &&
    [ -z "$(git config --global --get githooks.trust.all)" ] &&
    git hooks trust forget --global ||
    exit 6

# Run with no option, default should be local
git hooks trust &&
    [ -f .githooks/trust-all ] &&
    [ "$(git config --local --get githooks.trust.all)" = "Y" ] ||
    exit 7

# Check the Git alias
git hooks trust --local &&
    git hooks trust revoke &&
    git hooks trust delete &&
    git hooks trust forget --local ||
    exit 8
