#!/bin/sh
# Test:
#   Cli tool: manage ignore files

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test085 && cd /tmp/test085 || exit 1

! git hooks ignore test || exit 2

git init || exit 3

! git hooks ignore || exit 4
! git hooks ignore pre-commit || exit 5

git hooks ignore test-root &&
    [ -f ".githooks/.ignore" ] &&
    grep -q "test-root" ".githooks/.ignore" || exit 6
git hooks ignore test-second &&
    [ -f ".githooks/.ignore" ] &&
    grep -q "test-root" ".githooks/.ignore" &&
    grep -q "test-second" ".githooks/.ignore" || exit 7

git hooks ignore pre-commit test-pc &&
    [ -f ".githooks/pre-commit/.ignore" ] &&
    grep -q "test-pc" ".githooks/pre-commit/.ignore" || exit 7

mkdir -p ".githooks/post-commit/.ignore" &&
    ! git hooks ignore post-commit test-fail &&
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
