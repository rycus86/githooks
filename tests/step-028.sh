#!/bin/sh
# Test:
#   Direct template execution: accept changes to hooks

mkdir -p ~/.githooks/release && cp /var/lib/githooks/*.sh ~/.githooks/release || exit 1
mkdir -p /tmp/test28 && cd /tmp/test28 || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo 'echo "First execution" >> /tmp/test028.out' >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=A ~/.githooks/release/base-template.sh "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "First execution" /tmp/test028.out; then
    echo "! Expected to execute the hook the first time"
    exit 1
fi

NUMBER_OF_CHECKSUMS=$(grep -r "pre-commit" .git/.githooks.checksums | wc -l)
if [ "$NUMBER_OF_CHECKSUMS" != "1" ]; then
    echo "! Expected to have one checksum entry"
    exit 1
fi

echo 'echo "Second execution" >> /tmp/test028.out' >.githooks/pre-commit/test &&
    ACCEPT_CHANGES=Y ~/.githooks/release/base-template.sh "$(pwd)"/.git/hooks/pre-commit

if ! grep -q "Second execution" /tmp/test028.out; then
    echo "! Expected to execute the hook the second time"
    exit 1
fi

NUMBER_OF_CHECKSUMS=$(grep -r "pre-commit" .git/.githooks.checksums | wc -l)
if [ "$NUMBER_OF_CHECKSUMS" != "2" ]; then
    echo "! Expected to have two checksum entries"
    exit 1
fi
