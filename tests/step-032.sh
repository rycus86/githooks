#!/bin/sh
# Test:
#   Direct template execution: choose to ignore the update

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

mkdir -p /tmp/test32 && cd /tmp/test32 || exit 1
git init || exit 1

sed -i 's/^# Version: .*/# Version: 0/' /var/lib/githooks/base-template.sh &&
    git config --global githooks.autoupdate.enabled Y ||
    exit 1

OUTPUT=$(
    sed -i 's|read -r EXECUTE_UPDATE </dev/tty|EXECUTE_UPDATE="N"|' /var/lib/githooks/base-template.sh &&
        HOOK_NAME=post-commit HOOK_FOLDER=$(pwd)/.git/hooks ACCEPT_CHANGES=A \
            sh /var/lib/githooks/base-template.sh
)

LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
if [ -z "$LAST_UPDATE" ]; then
    echo "! Update was expected to start"
    exit 1
fi

if ! echo "$OUTPUT" | grep -q "If you would like to disable auto-updates"; then
    echo "! Expected update output not found"
    echo "$OUTPUT"
    exit 1
fi
