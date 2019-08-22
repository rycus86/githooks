#!/bin/sh
# Test:
#   Run an install that preserves an existing hook in an existing repo

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test9/.githooks/pre-commit &&
    cd /tmp/test9 &&
    echo 'echo "In-repo" >> /tmp/test-009.out' >.githooks/pre-commit/test &&
    git init &&
    mkdir -p .git/hooks &&
    echo 'echo "Previous" >> /tmp/test-009.out' >.git/hooks/pre-commit &&
    chmod +x .git/hooks/pre-commit ||
    exit 1

echo 'n
y
/tmp/test9
' | sh /var/lib/githooks/install.sh || exit 1

git commit -m '' 2>/dev/null

if ! grep 'Previous' /tmp/test-009.out; then
    echo '! Saved hook was not run'
    exit 1
fi

if ! grep 'In-repo' /tmp/test-009.out; then
    echo '! Newly added hook was not run'
    exit 1
fi
