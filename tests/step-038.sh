#!/bin/sh
# Test:
#   Remember the start directory for searching existing repos

mkdir -p /tmp/start/dir || exit 1

echo 'n
y
/tmp/start
' | sh /var/lib/githooks/install.sh || exit 1

if [ "$(git config --global --get githooks.previous.searchdir)" != "/tmp/start" ]; then
    echo "! The search start directory is not recorded"
    exit 1
fi

cd /tmp/start/dir && git init || exit 1

sh /var/lib/githooks/install.sh || exit 1

if ! grep -r 'github.com/rycus86/githooks' /tmp/start/dir/.git/hooks; then
    echo "! Hooks were not installed"
    exit 1
fi
