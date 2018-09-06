#!/bin/sh
# Test:
#   Cli tool: list Githooks configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Unknown configuration

! sh /var/lib/githooks/cli.sh config set unknown || exit 2

# List configuration

mkdir -p /tmp/test086 && cd /tmp/test086 || exit 3

! sh /var/lib/githooks/cli.sh config list --local || exit 4 # not a Git repo

git init || exit 4

sh /var/lib/githooks/cli.sh config set single || exit 5
sh /var/lib/githooks/cli.sh config list --local | grep 'githooks.single.install' || exit 6
sh /var/lib/githooks/cli.sh config enable update || exit 7
sh /var/lib/githooks/cli.sh config list --global | grep 'githooks.autoupdate.enabled' || exit 8
sh /var/lib/githooks/cli.sh config list | grep 'githooks.single.install' &&
    sh /var/lib/githooks/cli.sh config list | grep 'githooks.autoupdate.enabled' ||
    exit 9

# Check the Git alias
! git hooks config set unknown || exit 10

git hooks config set single &&
    git hooks config list --local | grep 'githooks.single.install' || exit 11
git hooks config enable update &&
    git hooks config list --global | grep 'githooks.autoupdate.enabled' || exit 12
git hooks config list | grep 'githooks.single.install' &&
    git hooks config list | grep 'githooks.autoupdate.enabled' ||
    exit 13
