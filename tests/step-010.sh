#!/bin/sh
# Test:
#   Execute a dry-run installation

sh /var/lib/githooks/install.sh --dry-run || exit 1

mkdir -p /tmp/test10 && cd /tmp/test10 || exit 1
git init || exit 1

if grep -q 'https://github.com/rycus86/githooks' .git/hooks/pre-commit; then
    echo "! Hooks are unexpectedly installed"
    exit 1
fi
