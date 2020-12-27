#!/bin/sh
# Test:
#   Execute a dry-run installation

mkdir -p /tmp/test10/a && cd /tmp/test10/a || exit 1
git init || exit 1

echo 'n
y
/
' | "$GITHOOKS_BIN_DIR/installer" --stdin --dry-run || exit 1

mkdir -p /tmp/test10/b && cd /tmp/test10/b || exit 1
git init || exit 1

if grep -q 'https://github.com/rycus86/githooks' /tmp/test10/a/.git/hooks/pre-commit; then
    echo "! Hooks are unexpectedly installed in A"
    exit 1
fi

if grep -q 'https://github.com/rycus86/githooks' /tmp/test10/b/.git/hooks/pre-commit; then
    echo "! Hooks are unexpectedly installed in B"
    exit 1
fi
