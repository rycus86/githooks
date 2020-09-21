#!/bin/sh
# Test:
#   Run an install with multiple shared hooks set up, and verify those trigger properly

mkdir -p /tmp/shared/hooks-023-a.git/pre-commit &&
    echo 'echo "From shared hook A" >> /tmp/test-023.out' \
        >/tmp/shared/hooks-023-a.git/pre-commit/say-hello &&
    cd /tmp/shared/hooks-023-a.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p /tmp/shared/hooks-023-b.git/pre-commit &&
    echo 'echo "From shared hook B" >> /tmp/test-023.out' \
        >/tmp/shared/hooks-023-b.git/pre-commit/say-hello &&
    cd /tmp/shared/hooks-023-b.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

# change it and expect it to change it back
git config --global githooks.shared /tmp/shared/some-previous-example

# run the install, and set up shared repos
if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo 'n
y
/tmp/shared/hooks-023-a.git
/tmp/shared/hooks-023-b.git
' | sh /var/lib/githooks/install.sh || exit 1

else
    echo 'n
n
y
/tmp/shared/hooks-023-a.git
/tmp/shared/hooks-023-b.git
' | sh /var/lib/githooks/install.sh || exit 1

fi

git config --global --get-all githooks.shared | grep -v 'some-previous-example' || exit 1

mkdir -p /tmp/test023 && cd /tmp/test023 || exit 1
git init || exit 1

# verify that the hooks are installed and are working
git commit -m '' 2>/dev/null

if ! grep 'From shared hook A' /tmp/test-023.out; then
    echo "! The shared hooks A don't seem to be working"
    exit 1
fi

if ! grep 'From shared hook B' /tmp/test-023.out; then
    echo "! The shared hooks B don't seem to be working"
    exit 1
fi
