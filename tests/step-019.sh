#!/bin/sh
# Test:
#   Run an install, and set based on a custom template directory

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

# delete the built-in git template folder
rm -rf /usr/share/git-core/templates || exit 1

# shellcheck disable=SC2088
mkdir -p ~/.test-019/hooks &&
    git config --global init.templateDir '~/.test-019' ||
    exit 1

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test19 && cd /tmp/test19 || exit 1
git init || exit 1

# verify that the hooks are installed and are working
if ! grep 'github.com/rycus86/githooks' /tmp/test19/.git/hooks/pre-commit; then
    echo "! Githooks were not installed into a new repo"
    exit 1
fi
