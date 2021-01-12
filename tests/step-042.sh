#!/bin/sh
# Test:
#   Run a single-repo install and try the auto-update

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

LAST_UPDATE=$(git config --global --get githooks.autoUpdateCheckTimestamp)
if [ -n "$LAST_UPDATE" ]; then
    echo "! Update already marked as run"
    exit 1
fi

mkdir -p /tmp/start/dir && cd /tmp/start/dir || exit 1

git init || exit 1

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Installation failed"
    exit 1
fi

if ! "$GITHOOKS_BIN_DIR/cli" install; then
    echo "! Install into current repo failed"
    exit 1
fi

ARE_UPDATES_ENABLED=$(git config --global --get githooks.autoUpdateEnabled)
if [ "$ARE_UPDATES_ENABLED" != "true" ]; then
    echo "! Auto updates were expected to be enabled"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoUpdateCheckTimestamp)
if [ -n "$LAST_UPDATE" ]; then
    echo "! Update already marked as run"
    exit 1
fi

# Reset to trigger update
if ! (cd ~/.githooks/release && git reset --hard HEAD~1 >/dev/null); then
    echo "! Could not reset master to trigger update."
    exit 1
fi

git config --global --unset githooks.autoUpdateCheckTimestamp

OUTPUT=$(
    "$GITHOOKS_INSTALL_BIN_DIR/runner" "$(pwd)"/.git/hooks/post-commit 2>&1
)

if ! echo "$OUTPUT" | grep -q "All done! Enjoy!"; then
    echo "! Expected installation output not found"
    echo "$OUTPUT"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoUpdateCheckTimestamp)
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
