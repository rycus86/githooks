#!/bin/sh
# Test:
#   Cli tool: install githooks with global shared hook repositories and accept trusted repo

mkdir -p /tmp/shared130/trusted-shared.git/.githooks/pre-commit &&
    touch /tmp/shared130/trusted-shared.git/.githooks/trust-all &&
    echo 'echo "Hello"' >/tmp/shared130/trusted-shared.git/.githooks/pre-commit/sample-trusted &&
    cd /tmp/shared130/trusted-shared.git &&
    git init &&
    git add . &&
    git commit -a -m 'Initial commit' ||
    exit 1

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo 'n
y
/tmp/shared130/trusted-shared.git
y
' | sh /var/lib/githooks/install.sh || exit 2
else
    echo 'n
n
y
/tmp/shared130/trusted-shared.git

y
' | sh /var/lib/githooks/install.sh || exit 2

fi


mkdir -p /tmp/test130 && cd /tmp/test130 && git init || exit 3

# verify that the shared hook is trusted
if ! git hooks list | grep "sample-trusted" | grep -q "trusted"; then
    echo "! Unexpected cli list output (1)"
    exit 4
fi

# verify that the shared hook is automatically executed
touch test && git add . 

OUTPUT=$(git commit -m 'testing'  2>&1)
if ! echo "$OUTPUT" | grep -qE 'Hello'; then
    echo "! The shared hooks don't seem to be working"
    exit 5
fi

git hooks shared clear --all ||    exit 6


