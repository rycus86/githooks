#!/bin/sh
# Test:
#   Direct template execution: update shared hooks

git config --global githooks.testingTreatFileProtocolAsRemote "true"

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/shared/hooks-016-a.git/pre-commit &&
    echo 'echo "From shared hook A" >> /tmp/test-016.out' \
        >/tmp/shared/hooks-016-a.git/pre-commit/say-hello &&
    cd /tmp/shared/hooks-016-a.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p /tmp/shared/hooks-016-b.git/.githooks/pre-commit &&
    echo 'echo "From shared hook B" >> /tmp/test-016.out' \
        >/tmp/shared/hooks-016-b.git/.githooks/pre-commit/say-hello &&
    cd /tmp/shared/hooks-016-b.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p /tmp/test16 && cd /tmp/test16 || exit 1
git init || exit 1

mkdir -p .githooks &&
    git config --global githooks.shared '/tmp/shared/hooks-016-a.git' &&
    echo 'file:///tmp/shared/hooks-016-b.git' >.githooks/.shared &&
    HOOK_NAME=post-merge HOOK_FOLDER=$(pwd)/.git/hooks \
        sh ~/.githooks/release/base-template-wrapper.sh unused ||
    exit 1

HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
    sh ~/.githooks/release/base-template-wrapper.sh ||
    exit 1

if ! grep -q 'From shared hook A' /tmp/test-016.out; then
    echo "! The first shared hook was not run"
    exit 1
fi

if ! grep -q 'From shared hook B' /tmp/test-016.out; then
    echo "! The second shared hook was not run"
    exit 1
fi

# Trigger the shared hooks update
OUT=$(HOOK_NAME=post-merge HOOK_FOLDER=$(pwd)/.git/hooks \
    sh ~/.githooks/release/base-template-wrapper.sh unused 2>&1)
if ! echo "$OUT" | grep -q "Updating shared hooks from"; then
    echo "! Expected shared hooks update"
    exit 2
fi

# We should be skipping the shared hooks update the second time
OUT=$(HOOK_NAME=post-merge HOOK_FOLDER=$(pwd)/.git/hooks \
    sh ~/.githooks/release/base-template-wrapper.sh unused 2>&1)
if echo "$OUT" | grep -q "Updating shared hooks from"; then
    echo "! Expected to skip shared hooks update"
    exit 3
fi

# Fake an old update time for the shared hooks
CURRENT_TIME=$(date +%s)
git config --global githooks.sharedHooksUpdate.lastrun $((CURRENT_TIME - 99999))

# Trigger the shared hooks update again and expect to work again
OUT=$(HOOK_NAME=post-merge HOOK_FOLDER=$(pwd)/.git/hooks \
    sh ~/.githooks/release/base-template-wrapper.sh unused 2>&1)
if ! echo "$OUT" | grep -q "Updating shared hooks from"; then
    echo "! Expected shared hooks update"
    exit 4
fi
