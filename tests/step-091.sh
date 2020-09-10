#!/bin/sh
# Test:
#   Cli tool: manage previous search directory configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

! git hooks config unknown search-dir || exit 2
! git hooks config set search-dir || exit 3

git hooks config set search-dir /prev/search/dir &&
    git hooks config print search-dir | grep '/prev/search/dir' || exit 4
git hooks config reset search-dir &&
    git hooks config print search-dir | grep 'No previous search directory is set' || exit 5

# Check the Git alias
git hooks config set search-dir /prev/search/dir &&
    git hooks config print search-dir | grep '/prev/search/dir' || exit 10
git hooks config reset search-dir &&
    git hooks config print search-dir | grep 'No previous search directory is set' || exit 11
