#!/bin/sh
# Test:
#   Cli tool: manage global shared hook repository configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

! git hooks config unknown shared || exit 2
! git hooks config set shared || exit 3
git hooks config set shared file:///tmp/test/repo1.git && git hooks config print shared &&
    git hooks config print shared | grep 'test/repo1' || exit 4
git hooks config set shared file:///tmp/test/repo1.git file:///tmp/test/repo2.git || exit 5
git hooks config print shared | grep 'test/repo1' &&
    git hooks config print shared | grep 'test/repo2' || exit 6
git hooks config reset shared &&
    git hooks config print shared | grep 'None' || exit 7

# Check the Git alias
git hooks config set shared file:///tmp/test/repo1.git file:///tmp/test/repo2.git || exit 10
git hooks config print shared | grep 'test/repo1' &&
    git hooks config print shared | grep 'test/repo2' || exit 11
git hooks config reset shared &&
    git hooks config print shared | grep 'None' || exit 12
