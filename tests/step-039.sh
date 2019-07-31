#!/bin/sh
# Test:
#   Run a single-repo install successfully

mkdir -p /tmp/start/dir && cd /tmp/start/dir || exit 1

mkdir -p /tmp/empty &&
    GIT_TEMPLATE_DIR=/tmp/empty git init || exit 1

if ! sh /var/lib/githooks/install.sh --single; then
    echo "! Installation failed"
    exit 1
fi

if ! grep -r 'github.com/rycus86/githooks' /tmp/start/dir/.git/hooks; then
    echo "! Hooks were not installed"
    exit 1
fi
