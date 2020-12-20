#!/bin/sh
DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

set -u
set -e

"$DIR/test-clean-install.sh"

temp=$(mktemp -d)
"$GITHOOKS_REPO/githooks/build.sh" --build-flags '-tags debug,mock,dev' --bin-dir "$temp"
export GITHOOKS_DOWNLOAD_BIN_DIR="$temp"

sudo mkdir -p /usr/share/git-core-my/templates
if [ -f /usr/share/git-core/templates/hooks ]; then
    sudo mv -f /usr/share/git-core/templates/hooks /usr/share/git-core-my/templates
fi

sudo chown -R "$USER:$USER" /usr/share/git-core-my

echo "# git-lfs" | sudo tee "/usr/share/git-core-my/templates/pre-commit" >/dev/null 2>&1

echo 'y
y
y
' | "$GITHOOKS_BIN/installer" --clone-url "$GITHOOKS_REPO" \
    --clone-branch feature/go-refactoring \
    --stdin

cat /usr/share/git-core-my/templates/hooks/pre-commit

# verify that the hooks are installed and are working
if ! grep 'github.com/rycus86/githooks' /usr/share/git-core-my/templates/hooks/pre-commit; then
    echo "! Githooks were not installed template dir"
    exit 1
fi
