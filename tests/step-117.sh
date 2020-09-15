#!/bin/sh
# Test:
#   Test local urls of shared hooks to not be cloned and updated

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Make repo
mkdir -p /tmp/test117 && cd /tmp/test117 || exit 1
git init &&
    mkdir ".githooks" &&
    touch ".githooks/trust-all" &&
    git add . &&
    git commit -a -m 'Initial commit' ||
    exit 1

# Simulate a shared hook repo on the server
mkdir -p /tmp/shared/shared-server.git &&
    cd /tmp/shared/shared-server.git &&
    git init --bare &&
    git clone /tmp/shared/shared-server.git /tmp/shared/shared.git &&
    cd /tmp/shared/shared.git &&
    mkdir -p .githooks/pre-commit &&
    git config core.hooksPath "/dev/null" && # dont execute hooks in this repo!
    git checkout -b testbranch &&
    echo 'echo "Shared hook: test1"' >.githooks/pre-commit/sample-one &&
    git add . &&
    git commit -a -m 'Testing' &&
    git commit --allow-empty -m 'Testing...' &&
    git checkout -b testbranch2 &&
    echo 'echo "Shared hook: test2"' >.githooks/pre-commit/sample-one &&
    git commit -a -m 'Testing 2' &&
    git push -u origin testbranch testbranch2 ||
    exit 1

# Make the shared hook repo (clone, reset to a previous commit)
git clone /tmp/shared/shared.git --branch testbranch /tmp/shared/shared-clone.git &&
    cd /tmp/shared/shared-clone.git &&
    git reset --hard HEAD~ &&
    MD5SUM=$(find /tmp/shared/shared-clone.git -type f -exec md5sum {} \; | md5sum) ||
    exit 1

cd /tmp/test117 || exit 1
OUT=$(git hooks shared add --local /tmp/shared/shared-clone.git 2>&1)
# shellcheck disable=SC2181
if ! echo "$OUT" | grep -q "to the local shared hooks is forbidden"; then
    echo "! Expected adding local path to local shared hooks to fail: $OUT" >&2
    exit 1
fi

OUT=$(git hooks shared add --local file:///tmp/shared/shared-clone.git 2>&1)
# shellcheck disable=SC2181
if ! echo "$OUT" | grep -q "to the local shared hooks is forbidden"; then
    echo "! Expected adding local url to local shared hooks to fail: $OUT" >&2
    exit 1
fi

echo "file://///tmp/shared/shared-cloned.git" >.githooks/.shared || exit 1

# Invoke shared hooks update
OUT=$(HOOK_NAME=post-merge HOOK_FOLDER=$(pwd)/.git/hooks \
    sh ~/.githooks/release/base-template-wrapper.sh unused 2>&1)
# shellcheck disable=SC2181
if echo "$OUT" | grep -q "Shared hook: test1" ||
    ! echo "$OUT" | grep -q "Update will be skipped" ||
    ! echo "$OUT" | grep -q "Local shared hooks contain a local path"; then
    echo "! Expected triggered shared hooks update to notify skipping local paths: $OUT" >&2
    exit 1
fi

OUT=$(git commit --allow-empty -m "Test shared hooks" 2>&1)
# shellcheck disable=SC2181
if echo "$OUT" | grep -q "Shared hook: test1" ||
    ! echo "$OUT" | grep -q "Local shared hooks contain a local path"; then
    echo "! Expected hooks to be not run: $OUT" >&2
    exit 1
fi
rm -f .githooks/.shared || exit 1

# Test listing output
if git hooks shared list --local | grep -q "shared-clone" ||
    git hooks shared list --all | grep -q "shared-clone"; then
    echo "! Expected to have an empty shared hooks list" >&2
    exit 1
fi

if ! git hooks shared add --global /tmp/shared/shared-clone.git; then
    echo "! Expected adding local path to global shared hook repository to succeed" >&2
    exit 1
fi

if git hooks shared list --local | grep -q "shared-clone" >/dev/null 2>&1 ||
    git hooks shared list | grep "shared-clone" | grep -qv "active"; then
    echo "! Expected global shared hook repo to be active" >&2
    exit 1
fi

git hooks config accept trusted || exit 1
git hooks shared update || exit 1

# shellcheck disable=SC2012
RESULT=$(find ~/.githooks/shared/ -type d -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
if [ -d ~/.githooks/shared ] || [ "$RESULT" != "0" ]; then
    echo "! Expected shared hooks to be not cloned" >&2
    exit 1
fi

OUT=$(git commit --allow-empty -m "Test shared hooks" 2>&1)
# shellcheck disable=SC2181
if ! echo "$OUT" | grep -q "Shared hook: test1"; then
    echo "! Expected global shared hook to be run: $OUT" >&2
    exit 1
fi

MD5SUM_NOW="$(find /tmp/shared/shared-clone.git -type f -exec md5sum {} \; | md5sum)"
if [ "$MD5SUM" != "$MD5SUM_NOW" ]; then
    echo "! Expected local hooks repository to be not touched $MD5SUM, $MD5SUM_NOW" >&2
    exit 1
fi

git hooks shared remove --global /tmp/shared/shared-clone.git
if [ -n "$(git config --global --get githooks.shared)" ]; then
    echo "! Expected to not have any global shared hooks repository set" >&2
    exit 1
fi

# Add local non-bare repo url to the global shared hooks
git hooks shared add --global /tmp/shared/shared-clone.git || exit 1
git hooks shared add --global file:///tmp/shared/shared-server.git@testbranch2 || exit 1
git hooks shared update || exit 1
git hooks shared list --all

# shellcheck disable=SC2012
RESULT=$(find ~/.githooks/shared/ -type d -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
if [ "$RESULT" != "1" ]; then
    echo "! Expected 1 shared hooks repo to be cloned $(ls ~/.githooks/shared/)" >&2
    exit 1
fi

OUT=$(git commit --allow-empty -m "Test shared hooks" 2>&1)
# shellcheck disable=SC2181
if ! echo "$OUT" | grep -q "Shared hook: test1" ||
    ! echo "$OUT" | grep -q "Shared hook: test2"; then
    echo "! Expected 2 global shared hook to be run: $OUT" >&2
    exit 1
fi

# Make normals shared hooks folder (no git)
git hooks shared purge || exit 1
git config --global --unset githooks.shared || exit 1
rm -rf /tmp/shared/shared-clone.git/.git || exit 1

git hooks shared add --global /tmp/shared/shared-clone.git || exit 1
OUT=$(git commit --allow-empty -m "Test shared hooks" 2>&1)
# shellcheck disable=SC2181
if ! echo "$OUT" | grep -q "Shared hook: test1"; then
    echo "! Expected 1 global shared hook to be run: $OUT" >&2
    exit 1
fi
