#!/bin/sh
# Test:
#   Run a single-repo install and try the auto-update

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
if [ "$ARE_UPDATES_ENABLED" != "Y" ]; then
    echo "! Auto updates were expected to be enabled"
    exit 1
fi

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ -n "$LAST_UPDATE" ]; then
    echo "! Update already marked as run"
    exit 1
fi

sed -i 's/^# Version: .*/# Version: 0/' /var/lib/githooks/base-template.sh ||
    exit 1

OUTPUT=$(
    sed -i 's|read -r EXECUTE_UPDATE </dev/tty|EXECUTE_UPDATE="Y"|' /var/lib/githooks/base-template.sh &&
        HOOK_NAME=post-commit HOOK_FOLDER=$(pwd)/.git/hooks \
            sh /var/lib/githooks/base-template.sh
)

if ! echo "$OUTPUT" | grep -q "All done! Enjoy!"; then
    echo "$OUTPUT"
    echo "! Expected installation output not found"
    exit 1
fi

if echo "$OUTPUT" | grep -q "Git hook template ready"; then
    echo "$OUTPUT"
    echo "! Unexpected installation output found"
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
