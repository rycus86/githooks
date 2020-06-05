#!/bin/sh
# Test:
#   Direct template execution: execute auto-update

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ -n "$LAST_UPDATE" ]; then
    echo "! Update already marked as run"
    exit 1
fi

mkdir -p /tmp/test29 && cd /tmp/test29 || exit 1
git init || exit 1

sed -i 's/^# Version: .*/# Version: 0/' /var/lib/githooks/base-template.sh &&
    git config --global githooks.autoupdate.enabled true ||
    exit 1

HOOK_NAME=post-commit HOOK_FOLDER=$(pwd)/.git/hooks ACCEPT_CHANGES=A \
    sh /var/lib/githooks/base-template.sh

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ -z "$LAST_UPDATE" ]; then
    echo "! Update did not run"
    exit 1
fi

CURRENT_TIME=$(date +%s)
ELAPSED_TIME=$((CURRENT_TIME - LAST_UPDATE))

if [ $ELAPSED_TIME -gt 5 ]; then
    echo "! Update did not execute properly"
    exit 1
fi
