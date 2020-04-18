#!/bin/sh
# Test:
#   Cli tool: run an update

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test063 &&
    cd /tmp/test063 &&
    git init ||
    exit 1

sed 's/# Version: /# Version: 0/' /var/lib/githooks/cli.sh >/tmp/cli-0 &&
    mv /tmp/cli-0 /var/lib/githooks/cli.sh &&
    chmod +x /var/lib/githooks/cli.sh ||
    exit 1

if ! sh /var/lib/githooks/cli.sh update; then
    echo "! Failed to run the update"
    exit 1
fi

if ! git hooks update; then
    echo "! The Git alias integration failed"
    exit 1
fi
