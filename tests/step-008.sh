#!/bin/sh
# Test:
#   Run an install that preserves an existing hook in the templates directory

echo 'echo "Previous" >> /tmp/test-008.out' \
    > /usr/share/git-core/templates/hooks/pre-commit && \
    chmod +x /usr/share/git-core/templates/hooks/pre-commit \
    || exit 1

sh /var/lib/githooks/install.sh || exit 1

mkdir -p /tmp/test8/.githooks/pre-commit && \
    cd /tmp/test8 && \
    echo 'echo "In-repo" >> /tmp/test-008.out' > .githooks/pre-commit/test && \
    git init && \
    (git commit -m '' ; exit 0) \
    || exit 1

if ! grep 'Previous' /tmp/test-008.out; then
    echo '! Saved hook was not run'
    exit 1
fi

if ! grep 'In-repo' /tmp/test-008.out; then
    echo '! Newly added hook was not run'
    exit 1
fi
