#!/bin/sh
# Test:
#   Cli tool: manage trusted repository configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test093 && cd /tmp/test093 || exit 2

! git hooks config accept trusted || exit 3

git init || exit 4

! git hooks config unknown trusted || exit 5

git hooks config accept trusted &&
    git hooks config print trusted | grep 'trusts all hooks' || exit 6
git hooks config deny trusted &&
    git hooks config print trusted | grep 'does NOT trust hooks' || exit 7
git hooks config reset trusted &&
    git hooks config print trusted | grep 'does NOT have' || exit 8

# Check the Git alias
git hooks config accept trusted &&
    git hooks config print trusted | grep 'trusts all hooks' || exit 10
git hooks config deny trusted &&
    git hooks config print trusted | grep 'does NOT trust hooks' || exit 11
git hooks config reset trusted &&
    git hooks config print trusted | grep 'does NOT have' || exit 12
