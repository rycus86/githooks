#!/bin/sh
# Test:
#   Run a default install and verify the cli helper is installed

sh /var/lib/githooks/install.sh || exit 1

if ! git hooks version; then
    echo "! The command line helper tool is not available"
    exit 1
fi
