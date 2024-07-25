#!/bin/sh
# Test:
#   Cli tool: install githooks with global shared hook repositories and accept trusted repo

mkdir -p /tmp/shared/trusted-shared.git/.githooks/pre-commit &&
    touch /tmp/shared/trusted-shared.git/.githooks/trust-all
    echo 'echo "Hello"' >/tmp/shared/trusted-shared.git/.githooks/pre-commit/sample-trusted &&
    exit 1

echo 'n
y
/tmp/shared/trusted-shared.git
y
' | sh /var/lib/githooks/install.sh || exit 2

mkdir -p /tmp/test130 && cd /tmp/test130 && git init || exit 3

# verify that the shared hook is trusted
if ! git hooks list | grep "sample-trusted" | grep -q "trusted"; then
    echo "! Unexpected cli list output (1)"
    exit 4
fi

# verify that the shared hook is automatically executed
touch test && git add . && git commit -m '' 2>/dev/null

if ! grep 'Hello' /tmp/test130.out; then
    echo "! The shared hooks don't seem to be working"
    exit 1
fi

git hooks shared clear --all &&
    git hooks shared purge ||
    exit 5


