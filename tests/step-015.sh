#!/bin/sh
# Test:
#   Direct template execution: ignoring some hooks

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/test15 && cd /tmp/test15 || exit 1
git init || exit 1

mkdir -p .githooks/pre-commit &&
    echo 'exit 1' >.githooks/pre-commit/test.first &&
    echo 'exit 1' >.githooks/pre-commit/test.second &&
    echo 'echo "Third was run" >> /tmp/test015.out' >.githooks/pre-commit/test.third &&
    echo '#!/bin/sh' >.githooks/pre-commit/test.fourth &&
    echo 'echo "Fourth was run" >> /tmp/test015.out ' >.githooks/pre-commit/test.fourth &&
    chmod +x .githooks/pre-commit/test.fourth &&
    echo '*.first' >.githooks/.ignore &&
    echo '*.second' >.githooks/pre-commit/.ignore &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks \
        sh ~/.githooks/release/base-template-wrapper.sh ||
    exit 1

grep -q 'Third was run' /tmp/test015.out &&
    grep -q 'Fourth was run' /tmp/test015.out ||
    exit 1
