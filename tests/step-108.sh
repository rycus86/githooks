#!/bin/sh
# Test:
#   Custom installation prefix test

TEST_PREFIX_DIR="/tmp/githooks"
sh /var/lib/githooks/install.sh --prefix "$TEST_PREFIX_DIR" || exit 1

if [ ! -d "$TEST_PREFIX_DIR/.githooks" ] || [ ! -f "$TEST_PREFIX_DIR/.githooks/bin/githooks" ]; then
    echo "! Expected the install directory to be in \`$TEST_PREFIX_DIR\`"
    exit 1
fi

if [ "$(git config --global githooks.installDir)" != "$TEST_PREFIX_DIR/.githooks" ]; then
    echo "! Install directory in config \`$(git config --global githooks.installDir)\` is incorrect!"
    exit 1
fi

# Set a wrong install
git config --global githooks.installDir "$TEST_PREFIX_DIR/.githooks-notexisting"

if ! git hooks help 2>&1 | grep -q "Githooks installation is corrupt"; then
    echo "! Expected the installation to be corrupt (1)"
    exit 1
fi

mkdir -p /tmp/test104/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test104/.githooks/pre-commit/testing &&
    cd /tmp/test104 &&
    git init ||
    exit 1

echo A >A.txt
git add A.txt
if ! git commit -a -m "Test" 2>&1 | grep -q "Githooks installation is corrupt"; then
    echo "! Expected the installation to be corrupt (2)"
    exit 1
fi
