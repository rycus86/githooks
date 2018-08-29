#!/bin/sh
# Test:
#   Run an install that tries to install hooks into a non-existing directory

rm -rf /does/not/exist

echo 'n
y
/does/not/exist
' | sh /var/lib/githooks/install.sh

# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
    echo "! Expected to fail"
    exit 1
fi
