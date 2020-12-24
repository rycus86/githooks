#!/bin/sh
# Test:
#   Direct template execution: auto-update is not enabled

# Pseudo installation.
mkdir -p ~/.githooks/release &&
    cp -r /var/lib/githooks/githooks/bin ~/.githooks ||
    exit 1
mkdir -p /tmp/test30 && cd /tmp/test30 || exit 1
git init || exit 1

git config --global githooks.autoupdate.enabled false || exit 1

ACCEPT_CHANGES=A ~/.githooks/bin/runner "$(pwd)"/.git/hooks/post-commit

# shellcheck disable=SC2181
if cd ~/.githooks/release && git rev-parse HEAD; then
    echo "! Release clone cloned, but it should not have!"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ -n "$LAST_UPDATE" ]; then
    echo "! Update unexpectedly run"
    exit 1
fi
