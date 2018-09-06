#!/bin/sh
# Test:
#   Cli tool: manage global shared hook repository configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

! sh /var/lib/githooks/cli.sh config unknown shared || exit 2
! sh /var/lib/githooks/cli.sh config set shared || exit 3

sh /var/lib/githooks/cli.sh config set shared /tmp/test/repo1.git &&
    sh /var/lib/githooks/cli.sh config print shared | grep 'test_repo1' || exit 4
sh /var/lib/githooks/cli.sh config set shared /tmp/test/repo1.git /tmp/test/repo2.git || exit 5
sh /var/lib/githooks/cli.sh config print shared | grep 'test_repo1' &&
    sh /var/lib/githooks/cli.sh config print shared | grep 'test_repo2' || exit 6
sh /var/lib/githooks/cli.sh config reset shared &&
    sh /var/lib/githooks/cli.sh config print shared | grep 'None' || exit 7

# Check the Git alias
git hooks config set shared /tmp/test/repo1.git /tmp/test/repo2.git || exit 10
git hooks config print shared | grep 'test_repo1' &&
    git hooks config print shared | grep 'test_repo2' || exit 11
git hooks config reset shared &&
    git hooks config print shared | grep 'None' || exit 12
