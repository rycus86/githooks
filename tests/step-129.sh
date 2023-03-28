#!/bin/sh
# Test:
#   Cli tool: check skipping disabled hooks is not printed again within a day

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test129/.githooks/pre-commit &&
    echo 'echo "Hello first"' >/tmp/test129/.githooks/pre-commit/first &&
    echo 'echo "Hello second"' >/tmp/test129/.githooks/pre-commit/second &&
    cd /tmp/test129 &&
    git init ||
    exit 1

echo '1' >testing && git add testing || exit 2
OUTPUT=$(ACCEPT_CHANGES=D git commit -am 'Commit 1' 2>&1)
if ! echo "$OUTPUT" | grep -qE 'Disabled .*/first'; then
    echo "! Expected output not found"
    echo "$OUTPUT"
    exit 3
fi

echo '2' >testing && git add testing || exit 4
OUTPUT=$(git commit -m 'Commit 2' 2>&1)
if ! echo "$OUTPUT" | grep -qE 'Skipping disabled .*/first'; then
    echo "! Expected output not found"
    echo "$OUTPUT"
    exit 5
fi

echo '3' >testing && git add testing || exit 6
OUTPUT=$(git commit -m 'Commit 3' 2>&1)
if echo "$OUTPUT" | grep -qE 'Skipping disabled .*/first'; then
    echo "! Unexpected output found"
    echo "$OUTPUT"
    exit 7
fi
