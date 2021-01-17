#!/bin/sh
# Test:
#   Direct template execution: list of staged files (simple)

mkdir -p /tmp/test095/.githooks/pre-commit &&
    cd /tmp/test095 && git init ||
    exit 1

echo "Test" >>sample.txt
echo "Test" >>second.txt

cat <<EOF >.githooks/pre-commit/print-changes
for STAGED in \${STAGED_FILES}; do
    echo "staged: \${STAGED}" >> /tmp/test095.out
done
EOF

git add sample.txt second.txt

ACCEPT_CHANGES=A \
    "$GITHOOKS_TEST_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if ! grep 'staged: sample.txt' /tmp/test095.out; then
    echo "! Failed to find expected output (1)"
    exit 1
fi

if ! grep 'staged: second.txt' /tmp/test095.out; then
    echo "! Failed to find expected output (2)"
    exit 1
fi

if grep -vE '(sample|second)\.txt' /tmp/test095.out; then
    echo "! Unexpected additional output"
    exit 1
fi
