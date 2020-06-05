#!/bin/sh
# Test:
#   Test registering mechanism.

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

if [ -f ~/.githooks/autoupdate/registered ]; then
    echo "Expected the file to not exist"
    exit 1
fi

# Test that first git action registers repo 1
mkdir -p /tmp/test116.1 && cd /tmp/test116.1 &&
    git init &&
    git commit --allow-empty -m 'Initial commit' ||
    exit 1

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    if [ -f ~/.githooks/autoupdate/registered ]; then
        echo "Expected the file to not exist"
        exit 1
    fi
    # Skip further tests, because it does not apply for core hooks path
    exit 0
fi

if [ ! -f ~/.githooks/autoupdate/registered ]; then
    echo "Expected the file to be created"
    exit 1
fi

if [ "$(cat ~/.githooks/autoupdate/registered)" = "/tmp/test116/.git" ]; then
    echo "Expected correct content:"
    cat ~/.githooks/autoupdate/registered
    exit 2
fi

# Test that a first git action registers repo 2
# and repo 1 ist still registered
mkdir -p /tmp/test116.2 && cd /tmp/test116.2 &&
    git init &&
    git commit --allow-empty -m 'Initial commit' ||
    exit 1

if ! grep -q /tmp/test116.1/.git ~/.githooks/autoupdate/registered ||
    ! grep -q /tmp/test116.2/.git ~/.githooks/autoupdate/registered; then
    echo "! Expected correct content"
    cat ~/.githooks/autoupdate/registered
    exit 3
fi

# Test install to all repos 1,2,3
mkdir -p /tmp/test116.3 && cd /tmp/test116.3 && git init

echo 'Y
/tmp
' | sh /var/lib/githooks/install.sh || exit 1

if ! grep -q /tmp/test116.1/.git ~/.githooks/autoupdate/registered ||
    ! grep -q /tmp/test116.2/.git ~/.githooks/autoupdate/registered ||
    ! grep -q /tmp/test116.3/.git ~/.githooks/autoupdate/registered; then
    echo "! Expected all repos to be registered"
    cat ~/.githooks/autoupdate/registered
    exit 4
fi

# Test uninstall to only repo 1
echo 'Y
/tmp/test116.1
n
' | sh /var/lib/githooks/uninstall.sh || exit 1

if grep -q /tmp/test116.1 ~/.githooks/autoupdate/registered ||
    (! grep -q /tmp/test116.2 ~/.githooks/autoupdate/registered &&
        ! grep -q /tmp/test116.3 ~/.githooks/autoupdate/registered); then
    echo "! Expected repo 2 and 3 to still be registered"
    cat ~/.githooks/autoupdate/registered
    exit 5
fi

# Test total uninstall to all repos
echo 'Y
/tmp
' | sh /var/lib/githooks/uninstall.sh || exit 1

if [ -f ~/.githooks/autoupdate/registered ]; then
    echo "! Expected registered list to not exist"
    exit 1
fi
