#!/bin/sh
# Test:
#   Run an install that tries to install hooks into a non-existing directory

rm -rf /does/not/exist

OUTPUT=$(
    echo 'n
y
/does/not/exist
' | sh /var/lib/githooks/install.sh
)

if ! echo "$OUTPUT" | grep "Existing repositories won't get the Githooks hooks"; then
    echo "! Expected error message not found"
    echo "Output:"
    echo "$OUTPUT"
    exit 1
fi
