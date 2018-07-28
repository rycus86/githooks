#!/bin/sh
# Test:
#   Set up local repos, run the install and verify the hooks get installed

mkdir -p /tmp/test4/p001 && mkdir -p /tmp/test4/p002 || exit 1

cd /tmp/test4/p001 && git init || exit 1
cd /tmp/test4/p002 && git init || exit 1

if grep -r 'github.com/rycus86/githooks' /tmp/test4/; then
    echo "! Hooks were installed ahead of time"
    exit 1
fi

# run the install, and select installing the hooks into existing repos
echo 'y
/tmp/test4
' | sh /var/lib/githooks/install.sh || exit 1

if ! grep -r 'github.com/rycus86/githooks' /tmp/test4/p001/.git/hooks; then
    echo "! Hooks were not installed successfully"
    exit 1
fi

if ! grep -r 'github.com/rycus86/githooks' /tmp/test4/p002/.git/hooks; then
    echo "! Hooks were not installed successfully"
    exit 1
fi

