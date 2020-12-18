#!/bin/sh
set -u
set -e

mkdir -p /usr/share/git-core-my/templates &&
    mv -f /usr/share/git-core/templates/hooks /usr/share/git-core-my/templates

echo 'y
y
y
' | /var/lib/githooks/installer --clone-url /var/lib/githooks \
    --clone-branch feature/go-refactoring \
    --build-from-source \
    --build-flags="debug,mock,docker" \
    --stdin
