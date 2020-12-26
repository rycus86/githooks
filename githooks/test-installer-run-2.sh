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

sudo rm -rf /usr/share/git-core/templates/hooks || true
sudo mkdir -p /usr/share/git-core-my/templates/hooks &&
    sudo touch /usr/share/git-core-my/templates/hooks/pre-commit.sample

sudo chown -R "$USER:$USER" /usr/share/git-core-my

echo "# git-lfs" | sudo tee "/usr/share/git-core-my/templates/pre-commit" >/dev/null 2>&1

echo 'y
y
y
' | "$GITHOOKS_BIN_DIR/installer" --clone-url "$GITHOOKS_REPO" \
    --clone-branch feature/go-refactoring \
    --stdin

cat /usr/share/git-core-my/templates/hooks/pre-commit

# verify that the hooks are installed and are working
if ! grep 'github.com/rycus86/githooks' /usr/share/git-core-my/templates/hooks/pre-commit; then
    echo "! Githooks were not installed template dir"
    exit 1
fi
