#!/bin/sh
# Test:
#   Direct template execution: auto-update is not due yet

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
CURRENT_TIME=$(date +%s)
MOCK_LAST_RUN=$((CURRENT_TIME - 5))

git config --global githooks.autoupdate.lastrun $MOCK_LAST_RUN || exit 1

mkdir -p /tmp/test31 && cd /tmp/test31 || exit 1
git init || exit 1

git config --global githooks.autoupdate.enabled true || exit 1

HOOK_NAME=post-commit HOOK_FOLDER=$(pwd)/.git/hooks ACCEPT_CHANGES=A \
    sh ~/.githooks/release/base-template-wrapper.sh

# shellcheck disable=SC2181
if cd ~/.githooks/release && git rev-parse HEAD; then
    echo "! Release clone was cloned, but it should not have!"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ "$LAST_UPDATE" != "$MOCK_LAST_RUN" ]; then
    echo "! Update did not behave as expected"
    exit 1
fi
