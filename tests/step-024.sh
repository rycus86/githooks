#!/bin/sh
# Test:
#   Run an install that unsets shared repositories

# change it and expect it to reset it
git config --global githooks.shared /tmp/shared/some-previous-example

# run the install, and set up shared repos
if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo 'n
y

' | sh /var/lib/githooks/install.sh || exit 1

else
    echo 'n
n
y

' | sh /var/lib/githooks/install.sh || exit 1

fi

SHARED_REPOS=$(git config --global --get githooks.shared)

if [ -n "$SHARED_REPOS" ]; then
    echo "! The shared hook repos are still set to: $SHARED_REPOS"
    exit 1
fi
