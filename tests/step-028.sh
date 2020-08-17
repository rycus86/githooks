#!/bin/sh
# Test:
#   Direct template execution: accept changes to hooks

mkdir -p /tmp/test28 && cd /tmp/test28 || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo 'echo "First execution" >> /tmp/test028.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks ACCEPT_CHANGES=A \
        sh /var/lib/githooks/base-template-wrapper.sh

if ! grep -q "First execution" /tmp/test028.out; then
    echo "! Expected to execute the hook the first time"
    exit 1
fi

NUMBER_OF_CHECKSUMS=$(grep -c "$(pwd)/.githooks/pre-commit/test" .git/.githooks.checksum)
if [ "$NUMBER_OF_CHECKSUMS" != "1" ]; then
    echo "! Expected to have one checksum entry"
    exit 1
fi

echo 'echo "Second execution" >> /tmp/test028.out' >.githooks/pre-commit/test &&
    HOOK_NAME=pre-commit HOOK_FOLDER=$(pwd)/.git/hooks ACCEPT_CHANGES=Y \
        sh /var/lib/githooks/base-template-wrapper.sh

if ! grep -q "Second execution" /tmp/test028.out; then
    echo "! Expected to execute the hook the second time"
    exit 1
fi

NUMBER_OF_CHECKSUMS=$(grep -c "$(pwd)/.githooks/pre-commit/test" .git/.githooks.checksum)
if [ "$NUMBER_OF_CHECKSUMS" != "2" ]; then
    echo "! Expected to have two checksum entries"
    exit 1
fi
