#!/bin/sh
# Test:
#   Run a single-repo install and try the auto-update

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ -n "$LAST_UPDATE" ]; then
    echo "! Update already marked as run"
    exit 1
fi

mkdir -p /tmp/start/dir && cd /tmp/start/dir || exit 1

git init || exit 1

if ! sh /var/lib/githooks/install.sh --single; then
    echo "! Installation failed"
    exit 1
fi

SETUP_AS_SINGLE_REPO=$(git config --get --local githooks.single.install)
if [ "$SETUP_AS_SINGLE_REPO" != "yes" ]; then
    echo "! Expected to be a single-repo install"
    exit 1
fi

ARE_UPDATES_ENABLED=$(git config --local --get githooks.autoupdate.enabled)
if [ "$ARE_UPDATES_ENABLED" != "true" ]; then
    echo "! Auto updates were expected to be enabled"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ -n "$LAST_UPDATE" ]; then
    echo "! Update already marked as run"
    exit 1
fi

# Test update again with single flag
sed -i 's/^# Version: .*/# Version: 0/' /var/lib/githooks/base-template.sh ||
    exit 1

OUTPUT=$(
    HOOK_NAME=post-commit HOOK_FOLDER=$(pwd)/.git/hooks EXECUTE_UPDATE=Y \
        sh /var/lib/githooks/base-template.sh 2>&1
)
if ! echo "$OUTPUT" | grep -iq "DEPRECATION WARNING: Single install" ||
    ! echo "$OUTPUT" | grep -iq "Install failed due to deprecated single install"; then
    echo "$OUTPUT"
    echo "! Expected installation to fail because of single install flag"
    exit 1
fi

# Test update again without single flag
git config --local --unset githooks.single.install || exit 1

sed -i 's/^# Version: .*/# Version: 0/' /var/lib/githooks/base-template.sh || exit 1
git config --global --unset githooks.autoupdate.lastrun

OUTPUT=$(
    HOOK_NAME=post-commit HOOK_FOLDER=$(pwd)/.git/hooks EXECUTE_UPDATE=Y \
        sh /var/lib/githooks/base-template.sh 2>&1
)

if ! echo "$OUTPUT" | grep -q "All done! Enjoy!"; then
    echo "$OUTPUT"
    echo "! Expected installation output not found"
    exit 1
fi

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
