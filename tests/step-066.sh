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
' | sh /var/lib/githooks/install.sh 2>&1
)

if ! echo "$OUTPUT" | grep "Existing repositories won't get the Githooks hooks"; then
    echo "$OUTPUT"
    echo "! Expected error message not found"
    exit 1
fi
