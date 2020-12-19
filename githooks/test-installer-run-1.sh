#!/bin/sh
set -u
set -e

rm -rf /usr/share/git-core/templates/hooks

echo 'n
y
/tmp/.test-020-templates
' | /var/lib/githooks/installer --clone-url /var/lib/githooks \
    --clone-branch feature/go-refactoring \
    --build-from-source \
    --build-flags="debug,mock,docker" \
    --stdin

mkdir -p /tmp/test20 && cd /tmp/test20 || exit 1
git init || exit 1

# verify that the hooks are installed and are working
if ! grep 'github.com/rycus86/githooks' /tmp/test20/.git/hooks/pre-commit; then
    echo "! Githooks were not installed into a new repo"
    exit 1
fi
