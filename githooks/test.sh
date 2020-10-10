#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_DIR=$(git rev-parse --show-toplevel)

set -e
set -u

function die() {
    echo "!! " "$@" >&2
    exit 1
}

tmp=$(mktemp -d)

git init "$tmp" || die "Could not make git init"
cd "$tmp" &&
    git config --local githooks.runner "$DIR/bin/runner" &&
    cp "$REPO_DIR/base-template-wrapper.sh" .git/hooks/pre-commit &&
    mkdir .githooks && touch .githooks/trust-all &&
    chmod +x .git/hooks/pre-commit &&
    echo "echo hello from old hook" >.git/hooks/pre-commit.replaced.githooks

git commit --allow-empty -m "Test commit"
