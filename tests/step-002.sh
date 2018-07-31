#!/bin/sh
# Test:
#   Run a simple install and verify a hook triggers properly

# run the default install
sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test2 && cd /tmp/test2 || exit 1
git init || exit 1

# add a pre-commit hook, execute and verify that it worked
mkdir -p .githooks/pre-commit &&
    echo 'echo "From githooks" > /tmp/hooktest' >.githooks/pre-commit/test ||
    exit 1

git commit -m '' 2>/dev/null

grep -q 'From githooks' /tmp/hooktest
