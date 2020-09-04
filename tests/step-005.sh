#!/bin/sh
# Test:
#   Run an install with shared hooks set up, and verify those trigger properly
mkdir -p /tmp/shared/hooks-005.git/pre-commit &&
    echo 'echo "From shared hook" > /tmp/test-005.out' \
        >/tmp/shared/hooks-005.git/pre-commit/say-hello || exit 1

cd /tmp/shared/hooks-005.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit'

# run the install, and set up shared repos
if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo 'n
y
file:///tmp/shared/hooks-005.git
' | sh /var/lib/githooks/install.sh || exit 1

else
    echo 'n
n
y
file:///tmp/shared/hooks-005.git
' | sh /var/lib/githooks/install.sh || exit 1

fi

mkdir -p /tmp/test5 && cd /tmp/test5 || exit 1
git init || exit 1

# verify that the hooks are installed and are working
git commit -m '' 2>/dev/null

if ! grep 'From shared hook' /tmp/test-005.out; then
    echo "! The shared hooks don't seem to be working"
    exit 1
fi
