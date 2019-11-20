#!/bin/sh
# Test:
#   Set up bare repos, run the install and verify the hooks get installed/uninstalled

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test109/p001 && mkdir -p /tmp/test109/p002 || exit 1

cd /tmp/test109/p001 && git init --bare || exit 1
cd /tmp/test109/p002 && git init --bare || exit 1

if grep -r 'github.com/rycus86/githooks' /tmp/test109/; then
    echo "! Hooks were installed ahead of time"
    exit 1
fi

# run the install, and select installing the hooks into existing repos
echo 'n
y
/tmp/test109
' | sh /var/lib/githooks/install.sh || exit 1

if ! grep -r 'github.com/rycus86/githooks' /tmp/test109/p001/hooks ||
    ! grep -r 'github.com/rycus86/githooks' /tmp/test109/p002/hooks; then
    echo "! Hooks were not installed successfully"
    exit 1
fi

echo 'y
/tmp/test109
' | sh /var/lib/githooks/uninstall.sh || exit 1

if grep -qr 'github.com/rycus86/githooks' /tmp/test109/p001/hooks ||
    grep -qr 'github.com/rycus86/githooks' /tmp/test109/p002/hooks; then
    echo "! Hooks were not uninstalled successfully"
    exit 1
fi
