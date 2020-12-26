#!/bin/sh
# Test:
#   Run an install, adding the intro README files into an existing repo

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test046/.githooks/pre-commit &&
    echo 'echo "Testing" > /tmp/test46.out' >/tmp/test046/.githooks/pre-commit/test &&
    cd /tmp/test046 ||
    exit 1

git init || exit 1

echo "n
y
/tmp/test046
y
" | /var/lib/githooks/githooks/bin/installer --stdin || exit 1

if ! grep "github.com/rycus86/githooks" /tmp/test046/.git/hooks/pre-commit; then
    echo "! Hooks were not installed"
    exit 1
fi

if ! grep "github.com/rycus86/githooks" /tmp/test046/.githooks/README.md; then
    echo "! README was not installed"
    exit 1
fi
