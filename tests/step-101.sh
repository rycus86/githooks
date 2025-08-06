#!/bin/sh
# Test:
#   Test that a large number of staged files does not cause an "argument list too long" error.

# run the default install
sh /var/lib/githooks/install.sh --non-interactive || exit 1

mkdir -p /tmp/test101 && cd /tmp/test101 || exit 2
git init || exit 3

# set up a pre-commit hook
# shellcheck disable=SC2016
mkdir -p .githooks/pre-commit &&
    echo 'echo "RefFile: $STAGED_FILES_REFERENCE" >> /tmp/test101.out;
if [ -n "$STAGED_FILES_REFERENCE" ]; then
     export STAGED_FILES="$(cat $STAGED_FILES_REFERENCE)";
fi;
echo "Hook executed for $STAGED_FILES" >> /tmp/test101.out
' >.githooks/pre-commit/test &&
    git hooks accept test || exit 4

# Create a large number of files
mkdir -p some/quite/long/directory/to/put/these/test/files/so/that/our/test/here/can/verify/lengths/better/and/again/some/quite/long/directory/to/put/these/test/files/so/that/our/test/here/can/verify/lengths/better/and/again/some/quite/long/directory/to/put/these/test/files/so/that/our/test/here/can/verify/lengths/better/and/again
for i in $(seq 1 5000); do
    touch "some/quite/long/directory/to/put/these/test/files/so/that/our/test/here/can/verify/lengths/better/and/again/some/quite/long/directory/to/put/these/test/files/so/that/our/test/here/can/verify/lengths/better/and/again/some/quite/long/directory/to/put/these/test/files/so/that/our/test/here/can/verify/lengths/better/and/again/some_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_long_file_name_$i.txt"
done

# Stage the files
git add . || exit 5

# Commit the files
# This should not fail with "argument list too long"
OUTPUT=$(git commit -m "Test commit with a large number of files." 2>&1)
if echo "$OUTPUT" | grep -q "Argument list too long"; then
    echo "! $OUTPUT"
    echo "! The commit failed with 'Argument list too long'"
    exit 6
fi

# Check that the commit was successful
if ! git log -1 | grep -q "Test commit with a large number of files."; then
    echo "! $OUTPUT"
    echo "! The commit was not successful"
    exit 7
fi

# Check that the hook was executed
if ! grep -q 'Hook executed for' /tmp/test101.out || ! grep -q '_long_file_name_1012.txt' /tmp/test101.out; then
    echo "! $OUTPUT"
    echo "! Could not verify the hook execution"
    exit 8
fi

# Make sure the temporary staged files reference file was deleted
REF_FILE=$(grep 'RefFile:' /tmp/test101.out | awk '{print $2}')
if [ -z "$REF_FILE" ]; then
    echo "! Staged files reference file not found in the output"
    exit 9
elif [ -f "$REF_FILE" ]; then
    echo "! Staged files reference file was not cleaned up"
    exit 9
fi

exit 0
