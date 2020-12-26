#!/bin/sh
# Test:
#   Run an install that preserves an existing hook in the templates directory

cd /usr/share/git-core/templates/hooks &&
    echo '#!/bin/sh' >>pre-commit &&
    echo 'echo "Previous" >> /tmp/test-008.out' >>pre-commit &&
    chmod +x pre-commit ||
    exit 1

/var/lib/githooks/githooks/bin/installer --stdin || exit 1

ls -al /usr/share/git-core/templates/hooks

mkdir -p /tmp/test8/.githooks/pre-commit &&
    cd /tmp/test8 &&
    echo 'echo "In-repo" >> /tmp/test-008.out' >.githooks/pre-commit/test &&
    git init ||
    exit 1

git commit -m ''

if ! grep 'Previous' /tmp/test-008.out; then
    echo '! Saved hook was not run'
    exit 1
fi

if ! grep 'In-repo' /tmp/test-008.out; then
    echo '! Newly added hook was not run'
    exit 1
fi
