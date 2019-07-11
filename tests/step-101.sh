#!/bin/sh
# Test:
#   Cli tool: manage app install/uninstall

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test101 && cd /tmp/test101 || exit 2

git init || exit 3

# Install
chmod u+x /var/lib/githooks/examples/tools/download/run
git hooks tools register download /var/lib/githooks/examples/tools/download || exit 4
grep "raw.githubusercontent.com" ~/".githooks/tools/download/run" || exit 5

if ! grep -q "raw.githubusercontent.com" ~/".githooks/tools/download/run"; then
    echo "! Register unsuccessful"
    exit 1
fi

# Uninstall
git hooks tools unregister download || exit 6
if [ -f ~/".githooks/tools/download/run" ]; then
    echo "! Unregister unsuccessful"
    exit 1
fi
