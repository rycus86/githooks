#!/bin/sh
# Test:
#   Cli tool: manage app install/uninstall

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

# Install
git hooks apps install download "/var/lib/githooks/apps/download" || exit 4
grep "raw.githubusercontent.com" "~/.githooks/apps/download/run.sh" || exit 5

if ! grep -q "raw.githubusercontent.com" "~/.githooks/apps/download/run.sh"; then
    echo "! Install unsuccessful"
    exit 1
fi

# Uninstall
git hooks apps uninstall download "/var/lib/githooks/apps/download" || exit 6
if [! -f "~/.githooks/apps/download/run.sh" ]; then
    echo "! Uninstall unsuccessful"
    exit 1
fi
