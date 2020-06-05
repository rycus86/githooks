#!/bin/sh
# Test:
#   Custom install prefix test

TEST_PREFIX_DIR="/tmp/githooks"
sh /var/lib/githooks/install.sh --prefix "$TEST_PREFIX_DIR" || exit 1

if [ ! -d "$TEST_PREFIX_DIR/.githooks" ] || [ ! -d "$TEST_PREFIX_DIR/.githooks/release" ]; then
    echo "! Expected the install directory to be in \`$TEST_PREFIX_DIR\`"
    exit 2
fi

if [ "$(git config --global githooks.installDir)" != "$TEST_PREFIX_DIR/.githooks" ]; then
    echo "! Install directory in config \`$(git config --global githooks.installDir)\` is incorrect!"
    exit 3
fi

# Set a wrong install
git config --global githooks.installDir "$TEST_PREFIX_DIR/.githooks-notexisting"

if ! git hooks help 2>&1 | grep -q "Githooks installation is corrupt"; then
    echo "! Expected the installation to be corrupt"
    exit 4
fi

mkdir -p /tmp/test108/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test108/.githooks/pre-commit/testing &&
    cd /tmp/test108 &&
    git init ||
    exit 5

echo A >A.txt
git add A.txt
if ! git commit -a -m "Test" 2>&1 | grep -q "Githooks installation is corrupt"; then
    echo "! Expected the installation to be corrupt"
    exit 6
fi
