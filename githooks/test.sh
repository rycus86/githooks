#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_DIR=$(git rev-parse --show-toplevel)

set -e

function die() {
    echo "!! " "$@" >&2
    exit 1
}


tmp=$(mktemp -d)

useOld="$1"

# Make shared hook repo
function makeShared() {
    mkdir -p "$tmp/shared1.git/pre-commit" &&
    echo 'echo "From shared hook 1"' \
        >"$tmp/shared1.git/pre-commit/say-hello" || exit 1
cd "$tmp/shared1.git" &&
    git init &&
    git add . &&
    git commit -m 'Initial commit'

mkdir -p "$tmp/shared2.git" &&
    echo 'echo "From shared hook 2"' \
        >"$tmp/shared2.git/pre-commit" &&
        chmod +x "$tmp/shared2.git/pre-commit" || exit 1
cd "$tmp/shared2.git" &&
    git init &&
    git add . &&
    git commit -m 'Initial commit'
}

makeShared &>/dev/null || die "Could not make shared repos"

# Make repo
mkdir -p "$tmp/repo"
git init "$tmp/repo" &>/dev/null || die "Could not make git init"
cd "$tmp/repo" &&
    rm -rf .git/hooks/* &&
    cp "$REPO_DIR/base-template-wrapper.sh" .git/hooks/pre-commit &&
    chmod +x .git/hooks/pre-commit &&
    echo -e "#!/bin/bash\n echo 'hello from old hook'" >.git/hooks/pre-commit.replaced.githook &&
    chmod +x .git/hooks/pre-commit.replaced.githook &&
    mkdir .githooks && touch .githooks/trust-all &&
    mkdir -p .githooks/pre-commit &&
    echo -e "#!/bin/bash\n echo 'hello from repo hook1'" >.githooks/pre-commit/monkey &&
    chmod +x .githooks/pre-commit/monkey &&
    echo -e "#!/bin/bash\n echo 'hello from repo hook2'" >.githooks/pre-commit/gaga &&
    chmod +x .githooks/pre-commit/gaga &&
    git config --local --add githooks.shared "$tmp/shared1.git" &&
    git config --local --add githooks.shared "$tmp/shared2.git" &&
    echo "file://$tmp/shared2.git" > .githooks/.shared

tree .git/hooks
tree .githooks

if [ "$useOld" != "--old" ]; then
    git config --local githooks.runner "$DIR/bin/runner"
fi

git config --local githooks.sharedHooksUpdateTriggers "pre-commit"

git commit --allow-empty -m "Test commit"
