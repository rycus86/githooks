#!/bin/sh
# Test:
#   Direct template execution: accept changes to hooks

mkdir -p "$GH_TEST_TMP/test28" && cd "$GH_TEST_TMP/test28" || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo "echo 'First execution' >> '$GH_TEST_TMP/test028.out'" >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=A "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "First execution" "$GH_TEST_TMP/test028.out"; then
    echo "! Expected to execute the hook the first time"
    exit 1
fi

NUMBER_OF_CHECKSUMS=$(grep -r "pre-commit" .git/.githooks.checksums | wc -l)
if [ "$NUMBER_OF_CHECKSUMS" != "1" ]; then
    echo "! Expected to have one checksum entry"
    exit 1
fi

echo "echo 'Second execution' >> '$GH_TEST_TMP/test028.out'" >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=Y "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "Second execution" "$GH_TEST_TMP/test028.out"; then
    echo "! Expected to execute the hook the second time"
    exit 1
fi

NUMBER_OF_CHECKSUMS=$(grep -r "pre-commit" .git/.githooks.checksums | wc -l)
if [ "$NUMBER_OF_CHECKSUMS" != "2" ]; then
    echo "! Expected to have two checksum entries"
    exit 1
fi
