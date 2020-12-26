#!/bin/sh
# Test:
#   Run an install, and let it search for the template dir

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

# move the built-in git template folder
mkdir -p /tmp/git-templates &&
    mv /usr/share/git-core/templates /tmp/git-templates/ &&
    rm -f /tmp/git-templates/templates/hooks/* &&
    touch /tmp/git-templates/templates/hooks/pre-commit.sample ||
    exit 1

# run the install, and let it search for the templates
echo 'y
y
y
y
' | /var/lib/githooks/githooks/bin/installer --stdin || exit 1

if ! [ -f /tmp/git-templates/templates/hooks/pre-commit ]; then
    # verify that a new hook file was installed
    echo "! Expected hook is not installed"
    exit 1
elif ! grep 'github.com/rycus86/githooks' /tmp/git-templates/templates/hooks/pre-commit; then
    # verify that the new hook is ours
    echo "! Expected hook doesn't have the expected contents"
    exit 1
fi

mkdir -p /tmp/test6 && cd /tmp/test6 || exit 1
git init || exit 1

# verify that the hooks are installed and are working
if ! grep 'github.com/rycus86/githooks' /tmp/test6/.git/hooks/pre-commit; then
    echo "! Githooks were not installed into a new repo"
    exit 1
fi
