#!/bin/sh

mkdir -p /shared/hooks-005.git/pre-commit && \
    echo 'echo "From shared hook" > /tmp/test-005.out' \
        > /shared/hooks-005.git/pre-commit/say-hello || exit 1

cd /shared/hooks-005.git && \
    git init && \
    git add . && \
    git commit -m 'Initial commit'

# run the install, and set up shared repos
echo 'n
y
/shared/hooks-005.git
' | sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test5 && cd /tmp/test5 || exit 1
git init || exit 1

# verify that the hooks are installed and are working
(git commit -m '' ; true)

if ! grep 'From shared hook' /tmp/test-005.out; then
    echo "! The shared hooks don't seem to be working"
    exit 1
fi

