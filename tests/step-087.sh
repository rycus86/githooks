#!/bin/sh
# Test:
#   Cli tool: manage update time configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Update time configuration

! sh /var/lib/githooks/cli.sh config unknown update-time || exit 2

sh /var/lib/githooks/cli.sh config print update-time | grep 'never' || exit 3

git config --global githooks.autoupdate.lastrun 123 &&
    sh /var/lib/githooks/cli.sh config print update-time | grep -v 'never' || exit 4

sh /var/lib/githooks/cli.sh config reset update-time &&
    sh /var/lib/githooks/cli.sh config print update-time | grep 'never' || exit 5

# Check the Git alias
git hooks config print update-time | grep 'never' || exit 10
git config --global githooks.autoupdate.lastrun 123 &&
    git hooks config print update-time | grep -v 'never' || exit 11
git hooks config reset update-time &&
    git hooks config print update-time | grep 'never' || exit 12
