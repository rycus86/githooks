#!/bin/sh
DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

set -u
set -e

"$DIR/test-clean-install.sh"

temp=$(mktemp -d)
"$GITHOOKS_REPO/githooks/build.sh" --build-flags '-tags debug,mock,dev' --bin-dir "$temp"
export GITHOOKS_DOWNLOAD_BIN_DIR="$temp"

sudo rm -rf /usr/share/git-core/templates/hooks

echo 'n
y
/tmp/.test-020-templates
' | "$GITHOOKS_BIN/installer" --clone-url "$GITHOOKS_REPO" \
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
