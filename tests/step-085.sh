#!/bin/sh
# Test:
#   Cli tool: manage ignore files

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test085 && cd /tmp/test085 || exit 1

! sh /var/lib/githooks/cli.sh ignore test || exit 2

git init || exit 3

! sh /var/lib/githooks/cli.sh ignore || exit 4
! sh /var/lib/githooks/cli.sh ignore pre-commit || exit 5

sh /var/lib/githooks/cli.sh ignore test-root &&
    [ -f ".githooks/.ignore" ] &&
    grep -q "test-root" ".githooks/.ignore" || exit 6
sh /var/lib/githooks/cli.sh ignore test-second &&
    [ -f ".githooks/.ignore" ] &&
    grep -q "test-root" ".githooks/.ignore" &&
    grep -q "test-second" ".githooks/.ignore" || exit 7

sh /var/lib/githooks/cli.sh ignore pre-commit test-pc &&
    [ -f ".githooks/pre-commit/.ignore" ] &&
    grep -q "test-pc" ".githooks/pre-commit/.ignore" || exit 7

mkdir -p ".githooks/post-commit/.ignore" &&
    ! sh /var/lib/githooks/cli.sh ignore post-commit test-fail &&
    [ ! -f ".githooks/post-commit/.ignore" ] || exit 8

rm -rf .githooks

# Check the Git alias
git hooks ignore test-root &&
    [ -f ".githooks/.ignore" ] &&
    grep -q "test-root" ".githooks/.ignore" || exit 9
git hooks ignore test-second &&
    [ -f ".githooks/.ignore" ] &&
    grep -q "test-root" ".githooks/.ignore" &&
    grep -q "test-second" ".githooks/.ignore" || exit 10
git hooks ignore pre-commit test-pc &&
    [ -f ".githooks/pre-commit/.ignore" ] &&
    grep -q "test-pc" ".githooks/pre-commit/.ignore" || exit 11
