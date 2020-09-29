#!/bin/sh
# Test:
#   Test legacy transform introduced in PR #125 by updating from 49464f09f0 to HEAD
#   - split global githooks.shared values : `legacy_transform_adjust_local_paths`
#   - move local paths in .shared to local githooks.shared : `legacy_transform_split_global_shared_entries`

cleanup() {
    # Remove the whole install to
    # not make external script which calls uninstall
    # to dispatch into this uninstall!
    git hooks uninstall --global >/dev/null 2>&1
}

trap 'cleanup' EXIT

git clone -c core.hooksPath=/dev/null https://github.com/rycus86/githooks.git ~/githooks-original

cd ~/githooks-original &&
    git branch master-old origin/master &&
    git checkout master &&
    git reset --hard 49464f09f0 || exit 1

# Install old version
if ! sh ~/githooks-original/install.sh --clone-url ~/githooks-original --clone-branch "master"; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Make shared hook repo
makeShared() {
    idx="$1"
    mkdir -p "/tmp/shared$idx.git" &&
        cd "/tmp/shared$idx.git" &&
        git init &&
        mkdir -p .githooks/pre-commit &&
        git config core.hooksPath "/dev/null" && # dont execute hooks in this repo!
        echo "printf 'Shared repo $idx: pre-commit,'" >.githooks/pre-commit/sample-one &&
        git add . &&
        git commit -a -m 'Testing 1' ||
        return 1
}

makeShared 1 || exit 1
makeShared 2 || exit 2
makeShared 3 || exit 3
makeShared 4 || exit 4

# Install global hooks
git config --global githooks.shared "file:///tmp/shared1.git,/tmp/shared2.git"

# Make repo with local paths in .shared file
mkdir -p /tmp/test119 && cd /tmp/test119 || exit 7
git init &&
    mkdir ".githooks" &&
    touch ".githooks/trust-all" &&
    echo "# Hooks A" >>.githooks/.shared &&
    echo "file:///tmp/shared3.git" >>.githooks/.shared &&
    echo "# Hooks B" >>.githooks/.shared &&
    echo "/tmp/shared4.git" >>.githooks/.shared &&
    git add . || exit 8

git hooks config accept trusted || exit 9
git hooks shared update || exit 10

OUT=$(git commit -a -m "Testing" 2>&1)
if ! echo "$OUT" | grep -q "Shared repo 1: pre-commit,Shared repo 2: pre-commit,Shared repo 3: pre-commit,Shared repo 4: pre-commit"; then
    echo "! Expected to have run 4 shared hooks: $OUT" >&2
    exit 10
fi

# Update to new version
git config --global githooks.testingTreatFileProtocolAsRemote "true"

cd ~/githooks-original &&
    git reset --hard master-old &&
    cp -r /var/lib/githooks/* ./ &&
    git commit -a -m "Current Changes: Simulating a merge with this feature branch" || exit 11

# Trigger update
git hooks shared purge || exit 12 # Just to make sure we really update the shared hooks during update
cd /tmp/test119 || exit 13
UPDATE_OUT=$(git hooks update 2>&1)
# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    echo "! Expected update to succeed: $UPDATE_OUT"
    exit 1
fi

# Check if we have multiple githook.shared values now
COUNT=$(git config --global --get-all githooks.shared | wc -l)
if [ "$COUNT" != "2" ]; then
    echo "! Expected 2 githooks.shared config variables after legacy transform"
    git config --global --get-all githooks.shared
    exit 1
fi

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    if ! echo "$UPDATE_OUT" | grep "DEPRECATION WARNING: Local paths for shared hook repositories"; then
        echo "! Expected deprecation warning to move local paths manually: $UPDATE_OUT"
        exit 1
    fi

    if [ "$(git config --global githooks.failOnNonExistingSharedHooks)" != "true" ]; then
        echo "! Expected githooks.failOnNonExistingSharedHooks to be activated to help the user fix the problem"
        exit 1
    fi

    # We are finished here, since we need to manually clean up...
else

    # Check if local path got moved to --local githooks.shared
    if grep "shared4" /tmp/test119/.githooks/.shared ||
        ! git config --local githooks.shared | grep -q "shared4"; then
        echo "! Expected local path to be moved after legacy transform"
        cat /tmp/test119/.githooks/.shared
        echo "githooks.shared: $(git config --local githooks.shared)"
        exit 1
    fi

    # We  dont need a hooks update
    # It should have been run by the update
    # git hooks shared update || exit 13

    # Check again if all hooks get executed
    OUT=$(git commit --allow-empty -m "Testing" 2>&1)
    if ! echo "$OUT" | grep -q "Shared repo 1: pre-commit" ||
        ! echo "$OUT" | grep -q "Shared repo 2: pre-commit" ||
        ! echo "$OUT" | grep -q "Shared repo 3: pre-commit" ||
        ! echo "$OUT" | grep -q "Shared repo 4: pre-commit"; then
        echo "! Expected to have run 4 shared hooks: $OUT" >&2
        exit 14
    fi
fi
