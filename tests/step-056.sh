#!/bin/sh
# Test:
#   Cli tool: disable a hook

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

mkdir -p /tmp/test056/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test056/.githooks/pre-commit/first &&
    echo 'echo "Hello"' >/tmp/test056/.githooks/pre-commit/second &&
    cd /tmp/test056 &&
    git init ||
    exit 1

if ! git hooks disable update | grep "git hooks update disable"; then
    echo "! Could not find expected output"
    exit 1
fi

if ! git hooks disable first; then
    echo "! Failed to disable a hook by name"
    exit 1
fi

if ! git hooks list | grep "first" | grep -q "disabled"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! git hooks list | grep "second" | grep -qv "disabled"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! git hooks disable pre-commit; then
    echo "! Failed to disable a hook by type"
    exit 1
fi

if ! git hooks list | grep "first" | grep -q "disabled"; then
    echo "! Unexpected cli list output (3)"
    exit 1
fi

if ! git hooks list | grep "second" | grep -q "disabled"; then
    echo "! Unexpected cli list output (4)"
    exit 1
fi

if ! git hooks disable || ! git hooks list; then
    echo "! The Git alias integration failed"
    exit 1
fi
