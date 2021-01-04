#!/bin/bash

DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
REPO_DIR=$(git rev-parse --show-toplevel)

set -e

die() {
    echo "!! " "$@" >&2
    exit 1
}

cleanUp() {
    if [ -d "$tmp" ]; then
        rm -rf "$tmp"
    fi
}

trap cleanUp EXIT INT TERM

tmp=$(mktemp -d)

useOld="$1"

# Make shared hook repo
makeShared() {
    mkdir -p "$tmp/shared1.git/pre-commit" &&
        echo 'echo "From shared hook 1"' \
            >"$tmp/shared1.git/pre-commit/say-hello" || exit 1
    cd "$tmp/shared1.git" &&
        git init --template="" &&
        git add . &&
        git commit -m 'Initial commit'

    mkdir -p "$tmp/shared2.git" &&
        echo -e '#!/bin/bash\necho "From shared hook 2"' \
            >"$tmp/shared2.git/pre-commit" &&
        chmod +x "$tmp/shared2.git/pre-commit" || exit 1
    cd "$tmp/shared2.git" &&
        git init --template="" &&
        git add . &&
        git commit -m 'Initial commit'

    mkdir -p "$tmp/shared3.git" &&
        echo -e '#!/usr/bin/env python\nprint("hello from python shared hook 3")' \
            >"$tmp/shared3.git/pre-commit" &&
        chmod +x "$tmp/shared3.git/pre-commit" || exit 1
    cd "$tmp/shared3.git" &&
        git init --template="" &&
        git add . &&
        git commit -m 'Initial commit'

    mkdir -p "$tmp/shared4.git" &&
        mkdir -p "$tmp/shared4.git/.githooks/pre-commit"
    echo -e '#!/usr/bin/env python\nprint("hello from python shared hook legacy")' \
        >"$tmp/shared4.git/.githooks/pre-commit/legacy" &&
        chmod +x "$tmp/shared4.git/.githooks/pre-commit/legacy" || exit 1
    cd "$tmp/shared4.git" &&
        git init --template="" &&
        git add . &&
        git commit -m 'Initial commit'
}

makeShared >/dev/null 2>&1 || die "Could not make shared repos"

# Make repo
mkdir -p "$tmp/repo"
git init "$tmp/repo" >/dev/null 2>&1 || die "Could not make git init"
cd "$tmp/repo" &&
    rm -rf .git/hooks/* &&
    cp "$REPO_DIR/base-template-wrapper.sh" .git/hooks/pre-commit &&
    chmod +x .git/hooks/pre-commit &&
    echo -e "#!/bin/bash\n echo 'hello from old hook'" >.git/hooks/pre-commit.replaced.githook &&
    chmod +x .git/hooks/pre-commit.replaced.githook &&
    mkdir .githooks && touch .githooks/trust-all &&
    mkdir -p .githooks/pre-commit &&
    echo -e "#!/bin/bash\n echo 'hello from repo hook monkey'" >.githooks/pre-commit/monkey &&
    chmod +x .githooks/pre-commit/monkey &&
    echo -e "#!/bin/bash\n echo 'hello from repo hook gaga'" >.githooks/pre-commit/gaga &&
    chmod +x .githooks/pre-commit/gaga &&
    git config --local --add githooks.shared "$tmp/shared1.git" &&
    git config --local --add githooks.shared "$tmp/shared2.git" &&
    git config --local --add githooks.shared "$tmp/shared4.git" &&
    echo "file://$tmp/shared2.git" >.githooks/.shared &&
    echo "file://$tmp/shared2.git" >>.githooks/.shared &&
    echo "file://$tmp/shared3.git" >>.githooks/.shared &&
    echo "file://$tmp/shared4.git" >>.githooks/.shared

# Make one hook disabled
echo "disabled> $tmp/shared1.git/pre-commit/say-hello" >.git/.githooks.checksum

tree .git/hooks
tree .githooks

if [ "$useOld" != "--old" ]; then
    git config --local githooks.runner "$DIR/../bin/runner"
fi

git config --local githooks.testingTreatFileProtocolAsRemote "true"
git config --local githooks.sharedHooksUpdateTriggers "pre-commit"

echo "Commit..."
git commit --allow-empty -m "Test commit"
echo "Commit finished"

echo "File: '.git/.githooks.checksum' :"
cat ".git/.githooks.checksum"

echo "Dir: '.git/.githooks.checksums' :"
tree '.git/.githooks.checksums'
