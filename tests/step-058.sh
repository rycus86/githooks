#!/bin/sh
# Test:
#   Cli tool: accept changes to a hook

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

mkdir -p /tmp/test058/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test058/.githooks/pre-commit/first &&
    echo 'echo "Hello"' >/tmp/test058/.githooks/pre-commit/second &&
    cd /tmp/test058 &&
    git init ||
    exit 1

if ! git hooks list | grep "first" | grep -q "pending"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! git hooks list | grep "second" | grep -q "pending"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! git hooks accept pre-commit/first; then
    echo "! Failed to accept a hook by relative path"
    exit 1
fi

if ! git hooks list | grep "first" | grep -q "active"; then
    echo "! Unexpected cli list output (3)"
    exit 1
fi

if ! git hooks list | grep "second" | grep -q "pending"; then
    echo "! Unexpected cli list output (4)"
    exit 1
fi

if ! git hooks accept .; then
    echo "! Failed to accept all hooks"
    exit 1
fi

if ! git hooks list | grep "first" | grep -q "active"; then
    echo "! Unexpected cli list output (5)"
    exit 1
fi

if ! git hooks list | grep "second" | grep -q "active"; then
    echo "! Unexpected cli list output (6)"
    exit 1
fi
