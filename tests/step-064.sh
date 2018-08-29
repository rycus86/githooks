#!/bin/sh
# Test:
#   Cli tool: list all help and usage

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test064 &&
    cd /tmp/test064 &&
    git init ||
    exit 1

OUTPUT=$(sh /var/lib/githooks/cli.sh help)

for SUBCOMMAND in $(echo "$OUTPUT" | grep '^  ' | awk '{ print $1 }'); do
    if ! sh /var/lib/githooks/cli.sh "$SUBCOMMAND" help; then
        echo "! Failed to print help for $SUBCOMMAND"
        exit 1
    fi

    if ! git hooks "$SUBCOMMAND" help; then
        echo "! The Git alias integration failed"
        exit 1
    fi
done
