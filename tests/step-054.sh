#!/bin/sh
# Test:
#   Cli tool: list current hooks per type

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test054/.githooks/pre-commit &&
    mkdir -p /tmp/test054/.githooks/post-commit &&
    echo 'echo "Hello"' >/tmp/test054/.githooks/pre-commit/pre-example &&
    echo 'echo "Hello"' >/tmp/test054/.githooks/post-commit/post-example &&
    cd /tmp/test054 &&
    git init ||
    exit 1

if ! sh /var/lib/githooks/cli.sh list pre-commit | grep "\\- pre-example"; then
    echo "! Unexpected cli list output"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list post-commit | grep "\\- post-example"; then
    echo "! Unexpected cli list output"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list post-commit | grep -v "pre-example"; then
    echo "! Unexpected cli list output"
    exit 1
fi

if ! git hooks list pre-commit || ! git hooks list post-commit; then
    echo "! The Git alias integration failed"
    exit 1
fi
