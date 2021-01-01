#!/bin/sh
# Test:
#   Direct template execution: fail on shared hooks

git config --global githooks.testingTreatFileProtocolAsRemote "true"

mkdir -p /tmp/shared/hooks-018.git/pre-commit &&
    echo 'exit 1' >/tmp/shared/hooks-018.git/pre-commit/fail &&
    cd /tmp/shared/hooks-018.git &&
    git init &&
    git add . &&
    git commit -m 'Initial commit' ||
    exit 1

mkdir -p /tmp/test18 && cd /tmp/test18 || exit 1
git init || exit 1

mkdir -p .githooks &&
    echo 'urls: - file:///tmp/shared/hooks-018.git' >.githooks/.shared.yaml &&
    "$GITHOOKS_EXE_GIT_HOOKS" shared update ||
    exit 1

"$GITHOOKS_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected to fail on shared hook execution"
    exit 1
fi
