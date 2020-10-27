#!/bin/sh
# Test:
#   Direct template execution: choose to ignore the update (non-single)

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/test076 && cd /tmp/test076 || exit 1
git init || exit 1

# Reset to trigger update
git config --global githooks.autoupdate.enabled true || exit 1

OUTPUT=$(
    ACCEPT_CHANGES=A EXECUTE_UPDATE=N \
        ~/.githooks/release/base-template.sh "$(pwd)"/.git/hooks/post-commit 2>&1
)

if ! cd ~/.githooks/release && git rev-parse HEAD; then
    echo "! Release clone was not cloned, but it should have!"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ -z "$LAST_UPDATE" ]; then
    echo "! Update was expected to start"
    exit 1
fi

if ! echo "$OUTPUT" | grep -q "git hooks update disable"; then
    echo "! Expected update output not found"
    echo "$OUTPUT"
    exit 1
fi
