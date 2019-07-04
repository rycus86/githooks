#!/bin/sh
# Test:
#   Direct template execution: execute auto-update

if ! curl --version &>/dev/null && ! wget --version &>/dev/null; then
    echo "Neither curl nor wget is available"
    exit 249
fi

if ! curl -fsSL --connect-timeout 3 https://github.com/rycus86/githooks >/dev/null 2>&1; then
    if ! wget -O- --timeout 3 https://github.com/rycus86/githooks >/dev/null 2>&1; then
        echo "Could not connect to GitHub"
        exit 249
    fi
fi

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ -n "$LAST_UPDATE" ]; then
    echo "! Update already marked as run"
    exit 1
fi

mkdir -p /tmp/test29 && cd /tmp/test29 || exit 1
git init || exit 1

sed -i 's/^# Version: .*/# Version: 0/' /var/lib/githooks/base-template.sh &&
    git config --global githooks.autoupdate.enabled Y ||
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
