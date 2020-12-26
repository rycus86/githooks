#!/bin/sh
# Test:
#   Run an install, skipping the intro README files

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test045/001 && cd /tmp/test045/001 && git init || exit 1
mkdir -p /tmp/test045/002 && cd /tmp/test045/002 && git init || exit 1

cd /tmp/test045 || exit 1

echo "n
y
/tmp/test045
s
" | /var/lib/githooks/githooks/bin/installer --stdin || exit 1

if ! grep "github.com/rycus86/githooks" /tmp/test045/001/.git/hooks/pre-commit; then
    echo "! Hooks were not installed into 001"
    exit 1
fi

if grep "github.com/rycus86/githooks" /tmp/test045/001/.githooks/README.md; then
    echo "! README was unexpectedly installed into 001"
    exit 1
fi

if ! grep "github.com/rycus86/githooks" /tmp/test045/002/.git/hooks/pre-commit; then
    echo "! Hooks were not installed into 002"
    exit 1
fi

if grep "github.com/rycus86/githooks" /tmp/test045/002/.githooks/README.md; then
    echo "! README was unexpectedly installed into 002"
    exit 1
fi
