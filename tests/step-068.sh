#!/bin/sh
# Test:
#   Run the cli tool in a directory that is not a Git repository

mkdir /tmp/not-a-git-repo && cd /tmp/not-a-git-repo || exit 1

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

for SUBCOMMAND in enable disable accept list; do
    if sh /var/lib/githooks/cli.sh "$SUBCOMMAND"; then
        echo "! Expected to fail: $SUBCOMMAND"
        exit 1
    fi

    if git hooks "$SUBCOMMAND"; then
        echo "! Expected the alias to fail: $SUBCOMMAND"
        exit 1
    fi
done
