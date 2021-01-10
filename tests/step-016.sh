#!/bin/sh
# Test:
#   Direct template execution: update shared hooks

git config --global githooks.testingTreatFileProtocolAsRemote "true"

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
    echo 'urls: - file:///tmp/shared/hooks-016-b.git' >.githooks/.shared.yaml &&
    "$GITHOOKS_BIN_DIR/runner" "$(pwd)"/.git/hooks/post-merge unused ||
    exit 1

"$GITHOOKS_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit ||
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
OUT=$("$GITHOOKS_BIN_DIR/runner" "$(pwd)"/.git/hooks/post-merge unused 2>&1)
if ! echo "$OUT" | grep -q "Updating shared hooks from"; then
    echo "! Expected shared hooks update"
    exit 1
fi
