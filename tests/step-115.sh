#!/bin/sh
# Test:
#   Set up bare repos, run the install and verify the hooks get installed/uninstalled

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test115
cd /tmp/test115 && git init --bare || exit 1

if grep -r 'github.com/rycus86/githooks' /tmp/test115/; then
    echo "! Hooks were installed ahead of time"
    exit 1
fi

mkdir -p ~/.githooks/templates
git config --global init.templateDir ~/.githooks/templates
templateDir=$(git config --global init.templateDir)

# run the install, and select installing hooks into existing repos
echo 'n
y
/tmp/test115
' | sh /var/lib/githooks/install.sh || exit 1

# check if hooks are inside the template folder.
for hook in pre-push pre-receive pre-commit; do
    if ! [ -f "$templateDir/hooks/$hook" ]; then
        echo "! Hooks were not installed successfully"
        exit 1
    fi
done
#shellcheck disable=2012
count="$(ls "$templateDir/hooks/" | wc -l)"
if [ "$count" != "19" ]; then
    echo "! Expected only server hooks to be installed ($count)"
    exit 1
fi
