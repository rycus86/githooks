#!/bin/sh
# Test:
#   Run an install that unsets shared repositories

# change it and expect it to reset it
git config --global githooks.shared /shared/some-previous-example

# run the install, and set up shared repos
echo 'n
n
y

' | sh /var/lib/githooks/install.sh || exit 1

SHARED_REPOS=$(git config --global --get githooks.shared)

if [ -n "$SHARED_REPOS" ]; then
    echo "! The shared hook repos are still set to: $SHARED_REPOS"
    exit 1
fi
