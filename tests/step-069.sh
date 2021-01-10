#!/bin/sh
# Test:
#   Run the cli tool with an invalid subcommand

mkdir /tmp/not-a-git-repo && cd /tmp/not-a-git-repo || exit 1

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

for SUBCOMMAND in '' ' ' 'x' 'y'; do
    if "$GITHOOKS_INSTALL_BIN_DIR/cli" "$SUBCOMMAND"; then
        echo "! Expected to fail: $SUBCOMMAND"
        exit 1
    fi

    if "$GITHOOKS_INSTALL_BIN_DIR/cli" "$SUBCOMMAND"; then
        echo "! Expected the alias to fail: $SUBCOMMAND"
        exit 1
    fi
done
