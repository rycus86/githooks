#!/bin/sh
# Test:
#   Run an install including the intro README files

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test043/001 && cd /tmp/test043/001 && git init || exit 1
mkdir -p /tmp/test043/002 && cd /tmp/test043/002 && git init || exit 1

cd /tmp/test043 || exit 1

echo "n
y
/tmp/test043
a
" | "$GITHOOKS_TEST_BIN_DIR/installer" --stdin || exit 1

if ! grep "github.com/rycus86/githooks" /tmp/test043/001/.git/hooks/pre-commit; then
    echo "! Hooks were not installed into 001"
    exit 1
fi

if ! grep "github.com/rycus86/githooks" /tmp/test043/001/.githooks/README.md; then
    echo "! README was not installed into 001"
    exit 1
fi

if ! grep "github.com/rycus86/githooks" /tmp/test043/002/.git/hooks/pre-commit; then
    echo "! Hooks were not installed into 002"
    exit 1
fi

if ! grep "github.com/rycus86/githooks" /tmp/test043/002/.githooks/README.md; then
    echo "! README was not installed into 002"
    exit 1
fi
