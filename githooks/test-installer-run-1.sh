#!/bin/sh
DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

set -u
set -e

cleanUp() {
    if [ -d "$tmp" ]; then
        rm -rf "$tmp"
    fi
    "$DIR/clean-githooks.sh"
}

tmp=$(mktemp -d)

trap cleanUp EXIT INT TERM

"$DIR/clean-githooks.sh"

"$GITHOOKS_REPO/githooks/build.sh" --build-flags '-tags debug,mock' --bin-dir "$tmp"

sudo rm -rf /usr/share/git-core/templates/hooks

echo 'n
y
/tmp/.test-020-templates
' | "$GITHOOKS_BIN_DIR/installer" --clone-url "$GITHOOKS_REPO" \
    --clone-branch feature/go-refactoring \
    --stdin
# --build-from-source \
# --build-tags="debug,mock,docker" \

mkdir -p /tmp/test20 && cd /tmp/test20 || exit 1
git init || exit 1

# verify that the hooks are installed and are working
if ! grep 'github.com/rycus86/githooks' /tmp/test20/.git/hooks/pre-commit >/dev/null 2>&1; then
    echo "! Githooks were not installed into a new repo"
    exit 1
fi
