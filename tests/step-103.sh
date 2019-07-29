#!/bin/sh
# Test:
#   Fail on not available shared hooks.

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/shared/hooks-103.git/pre-commit &&
    echo 'exit 0' >/tmp/shared/hooks-103.git/pre-commit/succeed &&
    cd /tmp/shared/hooks-103.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

# Install shared hook url into a repo.
mkdir -p /tmp/test103 && cd /tmp/test103 || exit 1
git init || exit 1
mkdir -p .githooks && echo '/tmp/shared/hooks-103.git' >.githooks/.shared || exit 1
git add .githooks/.shared
git hooks shared update

RESULT=$(ls -A ~/.githooks/shared 2>/dev/null)
if [ "$RESULT" = "" ]; then
    echo "! Expected shared hooks to be installed."
    exit 1
fi
git commit -m "Test" || exit 1

# Remove all shared hooks and make it fail
git hooks shared purge || exit 1
# Fail on not existing hooks
git config --global --add githooks.failOnNotExistingSharedHooks true || exit 1

# Clone a new one
echo "Cloning"
cd /tmp || exit 1
git clone /tmp/test103 test103-clone && cd test103-clone || exit 1

RESULT=$(ls -A ~/.githooks/shared 2>/dev/null)
if [ "$RESULT" = "" ]; then
    echo "! Expected shared hooks to be installed."
    exit 1
fi

# Remove all shared hooks
git hooks shared purge || exit 1

echo "Commiting"
# Make a commit
echo A >A || exit 1
git add A || exit 1
OUTPUT=$(git commit -a -m "Test" 2>&1)

# shellcheck disable=SC2181
if [ $? -eq 0 ] || ! echo "$OUTPUT" | grep -q "Failed to execute shared hook"; then
    echo "! Expected to fail on not availabe shared hooks. output:"
    echo "$OUTPUT"
    exit 1
fi

git hooks shared pull || exit 1

# Change url and try to make it fail
(cd ~/.githooks/shared/shared_hooks_103* &&
    git remote rm origin &&
    git remote add origin /some/other/url.git) || exit 1
# Make a commit
echo A >>A || exit 1
OUTPUT=$(git commit -a -m "Test" 2>&1)

# shellcheck disable=SC2181
if [ $? -eq 0 ] || ! (echo "$OUTPUT" | grep "The URL" | grep -q "is different"); then
    echo "! Expected to fail on not matching url. output:"
    echo "$OUTPUT"
    exit 1
fi
