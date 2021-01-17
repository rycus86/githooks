#!/bin/sh
# Test:
#   Fail on not available shared hooks.

git config --global githooks.testingTreatFileProtocolAsRemote "true"

if ! "$GITHOOKS_TEST_BIN_DIR/installer"; then
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
mkdir -p .githooks && echo 'urls: - file:///tmp/shared/hooks-103.git' >.githooks/.shared.yaml || exit 1
git add .githooks/.shared.yaml
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared update

# shellcheck disable=SC2012
RESULT=$(find ~/.githooks/shared/ -type f 2>/dev/null | wc -l)
if [ "$RESULT" = "0" ]; then
    echo "! Expected shared hooks to be installed."
    exit 1
fi

git commit -m "Test" || exit 1

# Remove all shared hooks and make it fail
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared purge || exit 1

if [ -d ~/.githooks/shared ]; then
    echo "! Expected shared hooks to be purged."
    exit 1
fi

# Test some random nonsense.
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config fail-on-non-existing-shared-hooks --enable --disable || exit 1
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config fail-on-non-existing-shared-hooks --enable --print || exit 1
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config fail-on-non-existing-shared-hooks --disable --print || exit 1
! "$GITHOOKS_INSTALL_BIN_DIR/cli" config fail-on-non-existing-shared-hooks --local --global --enable || exit 1

# Fail on not existing hooks
# Local on/ global off
if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" config fail-on-non-existing-shared-hooks --enable; then
    echo "! Enabling fail-on-non-existing-shared-hooks failed"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" config fail-on-non-existing-shared-hooks --local --print | grep -q "enabled"; then
    echo "! Expected fail-on-non-existing-shared-hooks to be enabled locally"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" config fail-on-non-existing-shared-hooks --global --print | grep -q "disabled"; then
    echo "! Expected fail-on-non-existing-shared-hooks to be disabled globally"
    exit 1
fi

if [ ! "$(git config --local --get githooks.failOnNonExistingSharedHooks)" = "true" ]; then
    echo "! Expected githooks.failOnNonExistingSharedHooks to be enabled locally"
    exit 1
fi

if git config --global --get githooks.failOnNonExistingSharedHooks; then
    echo "! Expected githooks.failOnNonExistingSharedHooks to be unset globally"
    exit 1
fi

# Local on / global on
if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" config fail-on-non-existing-shared-hooks --global --enable; then
    echo "! Enabling fail-on-non-existing-shared-hooks globally failed"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" config fail-on-non-existing-shared-hooks --global --print | grep -q "enabled"; then
    echo "! Expected fail-on-non-existing-shared-hooks to be enabled globally"
    exit 1
fi

if [ ! "$(git config --local --get githooks.failOnNonExistingSharedHooks)" = "true" ]; then
    echo "! Expected githooks.failOnNonExistingSharedHooks to be still enabled locally"
    exit 1
fi

if [ ! "$(git config --global --get githooks.failOnNonExistingSharedHooks)" = "true" ]; then
    echo "! Expected githooks.failOnNonExistingSharedHooks to be set globally"
    exit 1
fi

# Clone a new one
echo "Cloning"
cd /tmp || exit 1
git clone /tmp/test103 test103-clone && cd test103-clone || exit 1

# shellcheck disable=SC2012
RESULT=$(find ~/.githooks/shared/ -type f 2>/dev/null | wc -l)
if [ "$RESULT" = "0" ]; then
    echo "! Expected shared hooks to be installed."
    exit 1
fi

# Remove all shared hooks
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared purge || exit 1

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

"$GITHOOKS_INSTALL_BIN_DIR/cli" shared pull || exit 1

# Change url and try to make it fail
(cd ~/.githooks/shared/*shared-hooks-103* &&
    git remote rm origin &&
    git remote add origin /some/other/url.git) || exit 1
# Make a commit
echo A >>A || exit 1
OUTPUT=$(git commit -a -m "Test" 2>&1)

# shellcheck disable=SC2181
if [ $? -eq 0 ] || ! (echo "$OUTPUT" | grep "The remote" | grep -q "is different"); then
    echo "! Expected to fail on not matching url. output:"
    echo "$OUTPUT"
    exit 1
fi
