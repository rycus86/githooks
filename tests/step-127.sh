#!/bin/sh
# Test:
#   Cli tool: execute a hook on demand

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test127/.githooks/pre-commit &&
    echo 'echo "Hello first"' >/tmp/test127/.githooks/pre-commit/first.hook &&
    echo 'echo "Hello second"' >/tmp/test127/.githooks/pre-commit/second &&
    cd /tmp/test127 &&
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

if ! git hooks exec first | grep -q "Hello first"; then
    echo "! Expected output not found (1)"
    exit 1
fi

if ! git hooks exec pre-commit second | grep -q "Hello second"; then
    echo "! Expected output not found (2)"
    exit 1
fi

if ! git hooks exec --exact pre-commit second | grep -q "Hello second"; then
    echo "! Expected output not found (3)"
    exit 1
fi

if [ "$(git hooks exec pre-commit | grep -c "Hello")" -ne "2" ]; then
    echo "! Expected output not found (4)"
    exit 1
fi
