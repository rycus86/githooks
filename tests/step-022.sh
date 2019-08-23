#!/bin/sh
# Test:
#   Set up local repos, run the install and verify the hooks get installed (default directory)

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p ~/test022/p001 && mkdir -p ~/test022/p002 || exit 1

cd ~/test022/p001 && git init || exit 1
cd ~/test022/p002 && git init || exit 1

if grep -r 'github.com/rycus86/githooks' ~/test022/; then
    echo "! Hooks were installed ahead of time"
    exit 1
fi

# run the install, and select installing the hooks into existing repos
echo 'n
y

' | sh /var/lib/githooks/install.sh || exit 1

if ! grep -r 'github.com/rycus86/githooks' ~/test022/p001/.git/hooks; then
    echo "! Hooks were not installed successfully"
    exit 1
fi

if ! grep -r 'github.com/rycus86/githooks' ~/test022/p002/.git/hooks; then
    echo "! Hooks were not installed successfully"
    exit 1
fi

rm -rf ~/test022
