#!/bin/sh
# Test:
#   Run an install that tries to install hooks into a non-existing directory

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

rm -rf /does/not/exist

OUTPUT=$(
    echo 'n
y
/does/not/exist
' | "$GITHOOKS_TEST_BIN_DIR/installer" --stdin 2>&1
)

if ! echo "$OUTPUT" | grep "Answer must be an existing directory"; then
    echo "$OUTPUT"
    echo "! Expected error message not found"
    exit 1
fi
