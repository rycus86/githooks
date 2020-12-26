#!/bin/sh
# Test:
#   Test clone url and clone branch settings

if ! /var/lib/githooks/githooks/bin/installer --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

git hooks config clone-url "https://wuagadugu.git"
if git config githooks.cloneUrl | grep -q "wuagadugu"; then
    echo "Expected clone url to be set" >&2
    exit 1
fi

git hooks config clone-branch "gaga"
if git config githooks.cloneBranch | grep -q "wuagadugu"; then
    echo "Expected clone url to be set" >&2
    exit 1
fi
