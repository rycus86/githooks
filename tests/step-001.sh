#!/bin/sh

# run the default install
sh /var/lib/githooks.sh || exit 1

mkdir -p /tmp/test1 && \
    cd /tmp/test1 && \
    git init && \
    grep -q 'https://github.com/rycus86/githooks' .git/hooks/pre-commit
