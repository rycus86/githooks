#!/bin/sh
# Test:
#   PR #135: Bugfix: Test that init.templateDir is not set when using core.hooksPath.

if [ "$(id -u)" != "0" ] || ! echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "! Test needs root access and --use-core-hookspath."
    exit 249
fi

mkdir -p ~/.githooks/release && cp /var/lib/githooks/cli.sh ~/.githooks/release || exit 1

rm -rf /usr/share/git-core/templates/hooks || exit 1

/var/lib/githooks/githooks/bin/installer --stdin --non-interactive || exit 1

if [ -n "$(git config init.templateDir)" ]; then
    echo "! Expected to have init.templateDir not set!" >&2
    exit 1
fi
