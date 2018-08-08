#!/bin/sh
# Test:
#   Direct template execution: auto-update is not due yet

CURRENT_TIME=$(date +%s)
MOCK_LAST_RUN=$((CURRENT_TIME - 5))

git config --global githooks.autoupdate.lastrun $MOCK_LAST_RUN || exit 1

mkdir -p /tmp/test31 && cd /tmp/test31 || exit 1
git init || exit 1

sed -i 's/^# Version: .*/# Version: 0/' /var/lib/githooks/base-template.sh &&
    git config --global githooks.autoupdate.enabled Y ||
    exit 1

HOOK_NAME=post-commit HOOK_FOLDER=$(pwd)/.git/hooks ACCEPT_CHANGES=A \
    sh /var/lib/githooks/base-template.sh

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ "$LAST_UPDATE" != "$MOCK_LAST_RUN" ]; then
    echo "! Update did not behave as expected"
    exit 1
fi
