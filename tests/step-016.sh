#!/bin/sh
# Test:
#   Direct template execution: update shared hooks

git config --global githooks.testingTreatFileProtocolAsRemote "true"

mkdir -p "$GH_TEST_TMP/shared/hooks-016-a.git/pre-commit" &&
    echo "echo 'From shared hook A' >> '$GH_TEST_TMP/test-016.out'" \
        >"$GH_TEST_TMP/shared/hooks-016-a.git/pre-commit/say-hello" &&
    cd "$GH_TEST_TMP/shared/hooks-016-a.git" &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p "$GH_TEST_TMP/shared/hooks-016-b.git/.githooks/pre-commit" &&
    echo "echo 'From shared hook B' >> '$GH_TEST_TMP/test-016.out'" \
        >"$GH_TEST_TMP/shared/hooks-016-b.git/.githooks/pre-commit/say-hello" &&
    cd "$GH_TEST_TMP/shared/hooks-016-b.git" &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p "$GH_TEST_TMP/test16" && cd "$GH_TEST_TMP/test16" || exit 1
git init || exit 1

mkdir -p .githooks &&
    git config --global githooks.shared "$GH_TEST_TMP/shared/hooks-016-a.git" &&
    echo "urls: - file://$GH_TEST_TMP/shared/hooks-016-b.git" >.githooks/.shared.yaml &&
    "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/post-merge unused ||
    exit 1

"$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1

if ! grep -q 'From shared hook A' "$GH_TEST_TMP/test-016.out"; then
    echo "! The first shared hook was not run"
    exit 1
fi

if ! grep -q 'From shared hook B' "$GH_TEST_TMP/test-016.out"; then
    echo "! The second shared hook was not run"
    exit 1
fi

# Trigger the shared hooks update
OUT=$("$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/post-merge unused 2>&1)
if ! echo "$OUT" | grep -q "Updating shared hooks from"; then
    echo "! Expected shared hooks update"
    exit 1
fi
