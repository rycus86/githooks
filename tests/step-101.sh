#!/bin/sh
# Test:
#   Cli tool: manage disable configuration

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test101 && cd /tmp/test101 || exit 2

git init || exit 3

git hooks apps install download "/var/lib/githooks/apps/download" || exit 4
grep "raw.githubusercontent.com" "~/.githooks/ || exit 5

