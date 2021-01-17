#!/bin/sh
# Test:
#   Run a simple install and verify multiple hooks trigger properly

# run the default install
"$GITHOOKS_TEST_BIN_DIR/installer" || exit 1

mkdir -p /tmp/test3 && cd /tmp/test3 || exit 1
git init || exit 1

# set up 2 pre-commit hooks, execute them and verify that they worked
mkdir -p .githooks/pre-commit &&
    echo 'echo "Hook-1" >> /tmp/multitest' >.githooks/pre-commit/test1 &&
    echo 'echo "Hook-2" >> /tmp/multitest' >.githooks/pre-commit/test2 ||
    exit 1

git commit -m '' 2>/dev/null

grep -q 'Hook-1' /tmp/multitest && grep -q 'Hook-2' /tmp/multitest
