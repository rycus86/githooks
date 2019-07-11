#!/bin/sh
# Test:
#   Set up local repos, run the install and skip installing hooks into existing directories

mkdir -p ~/test100/p001 && mkdir -p ~/test100/p002 || exit 1

cd ~/test100/p001 && git init || exit 1
cd ~/test100/p002 && git init || exit 1

if grep -r 'github.com/rycus86/githooks' ~/test100/; then
    echo "! Hooks were installed ahead of time"
    exit 1
fi

# run the install, and skip installing the hooks into existing repos
echo 'n
y

' | sh /var/lib/githooks/install.sh --skip-install-into-existing || exit 1

if grep -r 'github.com/rycus86/githooks' ~/test100/; then
    echo "! Hooks were installed but shouldn't have"
    exit 1
fi

# run the install, and let it install into existing repos
echo 'n
y

' | sh /var/lib/githooks/install.sh

if ! grep -r 'github.com/rycus86/githooks' ~/test100/p001/.git/hooks; then
    echo "! Hooks were not installed successfully"
    exit 1
fi

if ! grep -r 'github.com/rycus86/githooks' ~/test100/p002/.git/hooks; then
    echo "! Hooks were not installed successfully"
    exit 1
fi

rm -rf ~/test100
