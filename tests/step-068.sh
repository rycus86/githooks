#!/bin/sh
# Test:
#   Run the cli tool in a directory that is not a Git repository

mkdir /tmp/not-a-git-repo && cd /tmp/not-a-git-repo || exit 1

if ! /var/lib/githooks/githooks/bin/installer --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

for SUBCOMMAND in enable disable accept trust list; do
    if git hooks "$SUBCOMMAND"; then
        echo "! Expected to fail: $SUBCOMMAND"
        exit 1
    fi

    if git hooks "$SUBCOMMAND"; then
        echo "! Expected the alias to fail: $SUBCOMMAND"
        exit 1
    fi
done
