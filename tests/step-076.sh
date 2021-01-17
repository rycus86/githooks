#!/bin/sh
# Test:
#   Direct template execution: choose to ignore the update (non-single)

mkdir -p "$GH_TEST_TMP/test076" && cd "$GH_TEST_TMP/test076" || exit 1
git init || exit 1

# Reset to trigger update
git config --global githooks.autoUpdateEnabled true || exit 1

OUTPUT=$(
    ACCEPT_CHANGES=A EXECUTE_UPDATE=N \
        "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/post-commit 2>&1
)

if ! cd ~/.githooks/release && git rev-parse HEAD; then
    echo "! Release clone was not cloned, but it should have!"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoUpdateCheckTimestamp)
if [ -z "$LAST_UPDATE" ]; then
    echo "! Update was expected to start"
    exit 1
fi

if ! echo "$OUTPUT" | grep -q "git hooks update disable"; then
    echo "! Expected update output not found"
    echo "$OUTPUT"
    exit 1
fi
