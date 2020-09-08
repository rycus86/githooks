#!/bin/sh
# Test:
#   Cli tool: manage disable configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test090 && cd /tmp/test090 || exit 2

! git hooks config set disable || exit 3 # not a Git repository

git init || exit 4

! git hooks config unknown disable || exit 5

git hooks config set disable &&
    git hooks config print disable | grep -v 'NOT' || exit 6
git hooks config reset disable &&
    git hooks config print disable | grep 'NOT' || exit 7

# Check the Git alias
git hooks config set disable &&
    git hooks config print disable | grep -v 'NOT' || exit 10
git hooks config reset disable &&
    git hooks config print disable | grep 'NOT' || exit 11
