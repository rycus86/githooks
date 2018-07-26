#!/bin/sh

# run the default install
sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test3 && cd /tmp/test3 || exit 1
git init || exit 1

# set up 2 pre-commit hooks, execute them and verify that they worked
mkdir -p .githooks/pre-commit && \
    echo 'echo "Hook-1" >> /tmp/multitest' > .githooks/pre-commit/test1 && \
    echo 'echo "Hook-2" >> /tmp/multitest' > .githooks/pre-commit/test2 && \
    (git commit -m '' ; exit 0) && \
    grep -q 'Hook-1' /tmp/multitest && grep -q 'Hook-2' /tmp/multitest
