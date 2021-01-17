#!/bin/sh
# Test:
#   Direct template execution: auto-update is not due yet

CURRENT_TIME=$(date +%s)
MOCK_LAST_RUN=$((CURRENT_TIME - 5))

git config --global githooks.autoUpdateCheckTimestamp $MOCK_LAST_RUN || exit 1

mkdir -p "$GH_TEST_TMP/test31" && cd "$GH_TEST_TMP/test31" || exit 1
git init || exit 1

git config --global githooks.autoUpdateEnabled true || exit 1

ACCEPT_CHANGES=A "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/post-commit

# shellcheck disable=SC2181
if cd ~/.githooks/release && git rev-parse HEAD; then
    echo "! Release clone was cloned, but it should not have!"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoUpdateCheckTimestamp)
if [ "$LAST_UPDATE" != "$MOCK_LAST_RUN" ]; then
    echo "! Update did not behave as expected"
    exit 1
fi
