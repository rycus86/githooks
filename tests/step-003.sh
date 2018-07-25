#!/bin/sh

# run the default install
sh /var/lib/githooks.sh || exit 1

mkdir -p /tmp/test3/.githooks/pre-commit && cd /tmp/test3 && \
    git init && \
    echo 'echo "Hook-1" >> /tmp/multitest' > .githooks/pre-commit/test1 && \
    echo 'echo "Hook-2" >> /tmp/multitest' > .githooks/pre-commit/test2 && \
    (git commit -m '' ; exit 0) && \
    grep -q 'Hook-1' /tmp/multitest && grep -q 'Hook-2' /tmp/multitest
