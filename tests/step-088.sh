#!/bin/sh
# Test:
#   Cli tool: manage single install configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Single install configuration

mkdir -p /tmp/test088 && cd /tmp/test088 || exit 2

! sh /var/lib/githooks/cli.sh config set single || exit 3

git init || exit 4

! sh /var/lib/githooks/cli.sh config unknown single || exit 5

sh /var/lib/githooks/cli.sh config set single &&
    sh /var/lib/githooks/cli.sh config print single | grep -v 'NOT' || exit 6
sh /var/lib/githooks/cli.sh config reset single &&
    sh /var/lib/githooks/cli.sh config print single | grep 'NOT' || exit 7

# Check the Git alias
git hooks config set single &&
    git hooks config print single | grep -v 'NOT' || exit 10
git hooks config reset single &&
    git hooks config print single | grep 'NOT' || exit 11
