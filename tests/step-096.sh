#!/bin/sh
# Test:
#   Direct template execution: list of staged files (special paths)

mkdir -p /tmp/test096/.githooks/pre-commit &&
    cd /tmp/test096 && git init ||
    exit 1

mkdir -p sub/folder\ with\ space/x
printf "Test" >>sub/test.txt
printf "Test" >>sub/folder\ with\ space/test.txt
printf "Test" >>sub/folder\ with\ space/x/test.txt
printf "Test" >>file\ with\ spaces.txt

cat <<EOF >.githooks/pre-commit/print-changes
IFS="
"
for STAGED in \${STAGED_FILES}; do
    echo ">\${STAGED}< "\$(cat "\${STAGED}" | wc -c) >> /tmp/test096.out
done
EOF

git add sub f*

ACCEPT_CHANGES=A \
    "$GITHOOKS_TEST_BIN_DIR/runner" "$(pwd)"/.git/hooks/pre-commit

if [ "$(wc -l </tmp/test096.out)" != "4" ]; then
    echo "! Unexpected number of output rows"
    exit 1
fi

if ! grep '>sub/folder with space/x/test.txt< 4' /tmp/test096.out; then
    echo "! Failed to find expected output"
    exit 1
fi
