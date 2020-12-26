#!/bin/sh
# Test:
#   Set up bare repos, run the install and verify the hooks get installed/uninstalled

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test109/p001 && mkdir -p /tmp/test109/p002 && mkdir -p /tmp/test109/p003 || exit 1

cd /tmp/test109/p001 && git init --bare || exit 1
cd /tmp/test109/p002 && git init --bare || exit 1

if grep -r 'github.com/rycus86/githooks' /tmp/test109/; then
    echo "! Hooks were installed ahead of time"
    exit 1
fi

mkdir -p ~/.githooks/templates/hooks
git config --global init.templateDir ~/.githooks/templates
templateDir=$(git config --global init.templateDir)

# run the install, and select installing hooks into existing repos
echo 'n
y
/tmp/test109
' | /var/lib/githooks/githooks/bin/installer --stdin || exit 1

if ! grep -qr 'github.com/rycus86/githooks' /tmp/test109/p001/hooks ||
    ! grep -qr 'github.com/rycus86/githooks' /tmp/test109/p002/hooks; then
    echo "! Hooks were not installed successfully"
    exit 1
fi

# check if only server hooks are installed.
for hook in pre-push pre-receive update post-receive post-update push-to-checkout pre-auto-gc; do
    if [ ! -f /tmp/test109/p001/hooks/$hook ]; then
        echo "! Server hooks were not installed successfully ('$hook')"
        exit 1
    fi
done
# shellcheck disable=SC2012
count=$(find /tmp/test109/p001/hooks/ -type f | wc -l)
if [ "$count" != "7" ]; then
    echo "! Expected only server hooks to be installed ($count)"
    exit 1
fi

cd /tmp/test109/p003 && git init --bare || exit 1
# check if only server hooks are installed.
for hook in pre-push pre-receive update post-receive post-update push-to-checkout pre-auto-gc; do
    if [ ! -f /tmp/test109/p003/hooks/$hook ]; then
        echo "! Server hooks were not installed successfully ('$hook')"
        exit 1
    fi
done

echo 'y
/tmp/test109
' | sh /var/lib/githooks/uninstall.sh || exit 1

if grep -qr 'github.com/rycus86/githooks' /tmp/test109/p001/hooks ||
    grep -qr 'github.com/rycus86/githooks' /tmp/test109/p002/hooks; then
    echo "! Hooks were not uninstalled successfully"
    exit 1
fi

# run the install, and select installing only server hooks into existing repos
echo 'n
y
/tmp/test109
' | /var/lib/githooks/githooks/bin/installer --stdin --only-server-hooks || exit 1

# check if only server hooks are inside the template folder.
for hook in pre-push pre-receive update post-receive post-update push-to-checkout pre-auto-gc; do
    if ! [ -f "$templateDir/hooks/$hook" ]; then
        echo "! Server hooks were not installed successfully"
        exit 1
    fi
done
# shellcheck disable=SC2012
count="$(find "$templateDir/hooks/" -type f | wc -l)"
if [ "$count" != "7" ]; then
    echo "! Expected only server hooks to be installed ($count)"
    exit 1
fi
