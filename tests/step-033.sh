#!/bin/sh
# Test:
#   Execute a dry-run, non-interactive installation

mkdir -p /tmp/test33/a && cd /tmp/test33/a || exit 1
git init || exit 1

sh /var/lib/githooks/install.sh --dry-run --non-interactive || exit 1

mkdir -p /tmp/test33/b && cd /tmp/test33/b || exit 1
git init || exit 1

if grep -q 'https://github.com/rycus86/githooks' /tmp/test33/a/.git/hooks/pre-commit; then
    echo "! Hooks are unexpectedly installed in A"
    exit 1
fi

if grep -q 'https://github.com/rycus86/githooks' /tmp/test33/b/.git/hooks/pre-commit; then
    echo "! Hooks are unexpectedly installed in B"
    exit 1
fi
