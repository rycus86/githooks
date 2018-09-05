#!/bin/sh
# Test:
#   Cli tool: manage Githooks configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Unknown configuration

! sh /var/lib/githooks/cli.sh config set unknown || exit 10

# Update time configuration

! sh /var/lib/githooks/cli.sh config unknown update-time || exit 20

sh /var/lib/githooks/cli.sh config print update-time | grep 'never' || exit 21

git config --global githooks.autoupdate.lastrun 123 &&
    sh /var/lib/githooks/cli.sh config print update-time | grep -v 'never' || exit 22

sh /var/lib/githooks/cli.sh config reset update-time &&
    sh /var/lib/githooks/cli.sh config print update-time | grep 'never' || exit 23

# Single repo configuration

mkdir -p /tmp/test086 && cd /tmp/test086 || exit 30

! sh /var/lib/githooks/cli.sh config set single || exit 31

git init || exit 32

! sh /var/lib/githooks/cli.sh config unknown single || exit 33

sh /var/lib/githooks/cli.sh config set single &&
    sh /var/lib/githooks/cli.sh config print single | grep -v 'NOT' || exit 34
sh /var/lib/githooks/cli.sh config reset single &&
    sh /var/lib/githooks/cli.sh config print single | grep 'NOT' || exit 35

# Check the Git alias
! git hooks config set unknown || exit 80

git hooks config print update-time | grep 'never' || exit 81
git config --global githooks.autoupdate.lastrun 123 &&
    git hooks config print update-time | grep -v 'never' || exit 82
git hooks config reset update-time &&
    git hooks config print update-time | grep 'never' || exit 83

git hooks config set single &&
    git hooks config print single | grep -v 'NOT' || exit 84
git hooks config reset single &&
    git hooks config print single | grep 'NOT' || exit 85
