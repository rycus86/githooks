#!/bin/sh

# run the default install
sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test2 && cd /tmp/test2 || exit 1
git init || exit 1

# add a pre-commit hook, execute and verify that it worked
mkdir -p .githooks/pre-commit && \
    echo 'echo "From githooks" > /tmp/hooktest' > .githooks/pre-commit/test && \
    (git commit -m '' ; exit 0) && \
    grep -q 'From githooks' /tmp/hooktest
