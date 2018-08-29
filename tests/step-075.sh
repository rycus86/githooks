#!/bin/sh
# Test:
#   Uninstall: start directory options for existing repos

mkdir -p /tmp/test074/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test074/.githooks/pre-commit/testing &&
    cd /tmp/test074 &&
    git init ||
    exit 1

echo 'y
y
/tmp
' | sh /var/lib/githooks/install.sh || exit 1

echo 'y

' | sh /var/lib/githooks/uninstall.sh || exit 2

echo 'y
/not/found
' | sh /var/lib/githooks/uninstall.sh

# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
    echo "! Uninstall unexpectedly finished"
    exit 1
fi
