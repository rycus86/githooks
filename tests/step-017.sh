#!/bin/sh
# Test:
#   Direct template execution: execute a previously saved hook

mkdir -p /tmp/test017 && cd /tmp/test017 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo 'echo "Direct execution" >> /tmp/test017.out' >.githooks/pre-commit/test &&
    echo '#!/bin/sh' >.git/hooks/pre-commit.replaced.githook &&
    echo 'echo "Previous hook" >> /tmp/test017.out' >>.git/hooks/pre-commit.replaced.githook &&
    chmod +x .git/hooks/pre-commit.replaced.githook &&
    "$GITHOOKS_TEST_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1

if ! grep -q 'Direct execution' /tmp/test017.out; then
    echo "! Direct execution didn't happen"
    exit 1
fi

if ! grep -q 'Previous hook' /tmp/test017.out; then
    echo "! Previous hook was not executed"
    exit 1
fi
