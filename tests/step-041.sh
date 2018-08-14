#!/bin/sh
# Test:
#   Run a single-repo, dry-run install successfully

mkdir -p /tmp/start/dir && cd /tmp/start/dir || exit 1

git init || exit 1

if ! sh /var/lib/githooks/install.sh --single --dry-run; then
    echo "! Installation failed"
    exit 1
fi

if grep -r 'github.com/rycus86/githooks' /tmp/start/dir/.git/hooks; then
    echo "! Hooks were not expected to be installed"
    exit 1
fi

rm -rf .git/ && git init || exit 1

# Run it once more for coverage
if ! sh -c "$(cat /var/lib/githooks/install.sh)" -- --single --dry-run; then
    echo "! Installation failed"
    exit 1
fi
