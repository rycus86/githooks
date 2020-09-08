#!/bin/sh
# Test:
#   Cli tool: manage update state configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Update state configuration

! git hooks config unknown update || exit 2
git hooks config reset update &&
    git hooks config print update | grep 'NOT' || exit 3
git hooks config enable update &&
    git hooks config print update | grep -v 'NOT' || exit 4
git hooks config disable update &&
    git hooks config print update | grep 'NOT' || exit 5

# Check the Git alias
git hooks config reset update &&
    git hooks config print update | grep 'NOT' || exit 10
git hooks config enable update &&
    git hooks config print update | grep -v 'NOT' || exit 11
git hooks config disable update &&
    git hooks config print update | grep 'NOT' || exit 12
