#!/bin/sh
# Test:
#   Cli tool: update shared hook repos

"$GITHOOKS_TEST_BIN_DIR/installer" || exit 1

mkdir -p /tmp/shared/first-shared.git/pre-commit &&
    cd /tmp/shared/first-shared.git &&
    echo 'echo "Hello"' >pre-commit/sample-one &&
    git init --template=/dev/null && git add . && git commit -m 'Testing' || exit 1

mkdir -p /tmp/shared/second-shared.git/pre-commit &&
    cd /tmp/shared/second-shared.git &&
    echo 'echo "Hello"' >pre-commit/sample-two &&
    git init --template=/dev/null && git add . && git commit -m 'Testing' || exit 1

mkdir -p /tmp/shared/third-shared.git/pre-commit &&
    cd /tmp/shared/third-shared.git &&
    echo 'echo "Hello"' >pre-commit/sample-three &&
    git init --template=/dev/null && git add . && git commit -m 'Testing' || exit 1

mkdir -p /tmp/test061/.githooks &&
    cd /tmp/test061 &&
    echo 'urls: - /tmp/shared/first-shared.git' >.githooks/.shared.yaml &&
    git init ||
    exit 1

git config --local githooks.shared 'file:///tmp/shared/second-shared.git' || exit 1
git config --global githooks.shared 'file:///tmp/shared/third-shared.git' || exit 1

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "sample-one" | grep -q "'shared:repo'"; then
    echo "! Unexpected cli list output (1)"
    exit 1
fi

if "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep -q "sample-two" ||
    "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep -q "sample-three"; then
    echo "! Unexpected cli list output (2)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep -qi "pending shared hooks"; then
    echo "! Unexpected cli list output (3)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" shared update; then
    echo "! Failed to update the shared hook repositories"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "sample-one" | grep -q "'shared:repo'"; then
    echo "! Unexpected cli list output (4)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "sample-two" | grep -q "'shared:local'"; then
    echo "! Unexpected cli list output (5)"
    exit 1
fi

if ! "$GITHOOKS_INSTALL_BIN_DIR/cli" list | grep "sample-three" | grep -q "'shared:global'"; then
    echo "! Unexpected cli list output (6)"
    exit 1
fi
