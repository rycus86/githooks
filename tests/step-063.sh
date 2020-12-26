#!/bin/sh
# Test:
#   Cli tool: run an update

/var/lib/githooks/githooks/bin/installer --stdin || exit 1

mkdir -p /tmp/test063 &&
    cd /tmp/test063 &&
    git init ||
    exit 1

# Reset to trigger update
if ! (cd ~/.githooks/release && git reset --hard HEAD~1 >/dev/null); then
    echo "! Could not reset master to trigger update."
    exit 1
fi

CURRENT="$(cd ~/.githooks/release && git rev-parse HEAD)"
if ! git hooks update; then
    echo "! Failed to run the update"
fi
AFTER="$(cd ~/.githooks/release && git rev-parse HEAD)"

if [ "$CURRENT" = "$AFTER" ]; then
    echo "! Release clone was not updated, but it should have!"
    exit 1
fi

if ! git hooks update; then
    echo "! The Git alias integration failed"
    exit 1
fi
