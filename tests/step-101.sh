#!/bin/sh
# Test:
#   Test that a large number of staged files does not cause an
#   "argument list too long" error.

# run the default install
sh /var/lib/githooks/install.sh --non-interactive || exit 1

mkdir -p /tmp/test101 && cd /tmp/test101 || exit 1
git init || exit 1

# set up a pre-commit hook
mkdir -p .githooks/pre-commit
cp /var/lib/githooks/.githooks/pre-commit/list-staged-files .githooks/pre-commit/

# Create a large number of files
for i in $(seq 1 2000); do
    touch "file_$i"
done

# Stage the files
git add .

# Commit the files
# This should not fail with "argument list too long"
OUTPUT=$(git commit -m "Test commit with a large number of files." 2>&1)
if echo "$OUTPUT" | grep -q "Argument list too long"; then
    echo "ERROR: The commit failed with 'Argument list too long'"
    exit 1
fi

# Check that the commit was successful
if ! git log -1 | grep -q "Test commit with a large number of files."; then
    echo "ERROR: The commit was not successful"
    exit 1
fi

exit 0
