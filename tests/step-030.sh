#!/bin/sh
# Test:
#   Direct template execution: auto-update is not enabled

mkdir -p "$GH_TEST_TMP/test30" && cd "$GH_TEST_TMP/test30" || exit 1
git init || exit 1

git config --global githooks.autoUpdateEnabled false || exit 1

ACCEPT_CHANGES=A "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/post-commit

# shellcheck disable=SC2181
if cd ~/.githooks/release && git rev-parse HEAD; then
    echo "! Release clone cloned, but it should not have!"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoUpdateCheckTimestamp)
if [ -n "$LAST_UPDATE" ]; then
    echo "! Update unexpectedly run"
    exit 1
fi
