#!/bin/sh

# run the default install
sh /var/lib/githooks.sh || exit 1

mkdir -p /tmp/test2 && cd /tmp/test2 && \
    git init && \
    mkdir -p .githooks/pre-commit && \
    echo 'echo "From githooks" > /tmp/hooktest' > .githooks/pre-commit/test && \
    (git commit -m '' ; exit 0) && \
    grep -q 'From githooks' /tmp/hooktest
