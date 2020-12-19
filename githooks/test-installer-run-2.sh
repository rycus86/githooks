#!/bin/sh
set -u
set -e

rm -rf /usr/share/git-core/templates/hooks

echo 'y
y
y
' | /var/lib/githooks/installer --clone-url /var/lib/githooks \
    --clone-branch feature/go-refactoring \
    --build-from-source \
    --build-flags="debug,mock,docker" \
    --stdin
