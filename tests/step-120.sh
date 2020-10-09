#!/bin/sh
# Test:
#   Custom install prefix test

TEST_PREFIX_DIR="/tmp/githooks"
mkdir -p ~/.githooks/release && cp /var/lib/githooks/cli.sh ~/.githooks/release || exit 1

rm -rf /usr/share/git-core/templates/hooks || exit 1

sh /var/lib/githooks/install.sh --non-interactive --prefix "$TEST_PREFIX_DIR" || exit 1

if [ "$(id -u)" != "0" ]; then
    echo "! Test needs root access."
    exit 249
fi

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    if [ -n "$(git config init.templateDir)" ]; then
        echo "! Expected to have init.templateDir not set!" >&2
        exit 1
    fi
fi
