#!/bin/sh
# Test:
#   Run an install, choosing never adding intro README files in the future

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test122/001 && cd /tmp/test122/001 && git init || exit 1
mkdir -p /tmp/test122/002 && cd /tmp/test122/002 && git init || exit 1
mkdir -p /tmp/test122/003 && cd /tmp/test122/003 && git init || exit 1

cd /tmp/test122/001 && echo "y
s
y" | sh /var/lib/githooks/install.sh --single || exit 1

if ! grep "github.com/rycus86/githooks" /tmp/test122/001/.git/hooks/pre-commit; then
    echo "! Hooks were not installed into 001"
    exit 1
fi

if grep "github.com/rycus86/githooks" /tmp/test122/001/.githooks/README.md; then
    echo "! README was unexpectedly installed into 001"
    exit 1
fi

if grep "github.com/rycus86/githooks" /tmp/test122/002/.git/hooks/pre-commit; then
    echo "! Hooks were installed ahead of time into 002"
    exit 1
fi

cd /tmp/test122/002 && sh /var/lib/githooks/install.sh --single || exit 1

if ! grep "github.com/rycus86/githooks" /tmp/test122/002/.git/hooks/pre-commit; then
    echo "! Hooks were not installed into 002"
    exit 1
fi

if grep "github.com/rycus86/githooks" /tmp/test122/002/.githooks/README.md; then
    echo "! README was unexpectedly installed into 002"
    exit 1
fi

if grep "github.com/rycus86/githooks" /tmp/test122/003/.git/hooks/pre-commit; then
    echo "! Hooks were installed ahead of time into 003"
    exit 1
fi

cd /tmp/test122 && echo "y
/tmp/test122/003" | sh /var/lib/githooks/install.sh || exit 1

if ! grep "github.com/rycus86/githooks" /tmp/test122/003/.git/hooks/pre-commit; then
    echo "! Hooks were not installed into 003"
    exit 1
fi

if grep "github.com/rycus86/githooks" /tmp/test122/003/.githooks/README.md; then
    echo "! README was unexpectedly installed into 003"
    exit 1
fi

# check that we can still do it through the CLI

if ! cd /tmp/test122/003 && git hooks readme add && [ -f /tmp/test122/003/.githooks/README.md ]; then
    echo "! Failed to add README file through the CLI"
    exit 1
fi
