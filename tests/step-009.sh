#!/bin/sh
# Test:
#   Run an install that preserves an existing hook in an existing repo

mkdir -p /tmp/test9/.githooks/pre-commit && \
    cd /tmp/test9 && \
    echo 'echo "In-repo" >> /tmp/test-009.out' > .githooks/pre-commit/test && \
    git init && \
    mkdir -p .git/hooks && \
    echo 'echo "Previous" >> /tmp/test-009.out' > .git/hooks/pre-commit && \
    chmod +x .git/hooks/pre-commit \
    || exit 1

echo 'y
/tmp/test9
' | sh /var/lib/githooks/install.sh || exit 1

(git commit -m '' ; exit 0)

if ! grep 'Previous' /tmp/test-009.out; then
    echo '! Saved hook was not run'
    exit 1
fi

if ! grep 'In-repo' /tmp/test-009.out; then
    echo '! Newly added hook was not run'
    exit 1
fi
