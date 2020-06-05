#!/bin/sh
# Test:
#   Direct template execution: choose to ignore the update (non-single)

mkdir -p /tmp/test076 && cd /tmp/test076 || exit 1
git init || exit 1

sed -i 's/^# Version: .*/# Version: 0/' /var/lib/githooks/base-template.sh &&
    git config --global githooks.autoupdate.enabled true ||
    exit 1

OUTPUT=$(
    HOOK_NAME=post-commit HOOK_FOLDER=$(pwd)/.git/hooks ACCEPT_CHANGES=A EXECUTE_UPDATE=N \
        sh /var/lib/githooks/base-template.sh
)

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
