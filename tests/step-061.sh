#!/bin/sh
# Test:
#   Cli tool: update shared hook repos

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/shared/first-shared.git/.githooks/pre-commit &&
    mkdir -p /tmp/shared/second-shared.git/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/shared/first-shared.git/.githooks/pre-commit/sample-one &&
    echo 'echo "Hello"' >/tmp/shared/second-shared.git/.githooks/pre-commit/sample-two &&
    (cd /tmp/shared/first-shared.git && git init && git add . && git commit -m 'Testing') &&
    (cd /tmp/shared/second-shared.git && git init && git add . && git commit -m 'Testing') ||
    exit 1

git config --global githooks.shared '/tmp/shared/first-shared.git' || exit 1

mkdir -p /tmp/test061/.githooks &&
    echo '/tmp/shared/second-shared.git' >/tmp/test061/.githooks/.shared &&
    cd /tmp/test061 &&
    git init ||
    exit 1

if sh /var/lib/githooks/cli.sh list | grep -q "sample"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh pull; then
    echo "! Failed to update the shared hook repositories"
    exit 1
fi

if ! sh /var/lib/githooks/cli.sh list | grep -q "sample"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! git hooks pull || ! git hooks list; then
    echo "! The Git alias integration failed"
    exit 1
fi
