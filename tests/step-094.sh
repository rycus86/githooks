#!/bin/sh
# Test:
#   Cli tool: run an installation

if ! curl --version &>/dev/null && ! wget --version &>/dev/null; then
    echo "Neither curl nor wget is available"
    exit 249
fi

if ! curl -fsSL --connect-timeout 3 https://github.com/rycus86/githooks >/dev/null 2>&1; then
    if ! wget -O- --timeout 3 https://github.com/rycus86/githooks >/dev/null 2>&1; then
        echo "Could not connect to GitHub"
        exit 249
    fi
fi

mkdir -p /tmp/test094/a /tmp/test094/b /tmp/test094/c &&
    cd /tmp/test094/a && git init &&
    cd /tmp/test094/b && git init ||
    exit 1

sed 's/# Version: /# Version: 0/' /var/lib/githooks/cli.sh >/tmp/cli-0 &&
    mv /tmp/cli-0 /var/lib/githooks/cli.sh &&
    chmod +x /var/lib/githooks/cli.sh ||
    exit 1

if ! sh /var/lib/githooks/cli.sh install; then
    echo "! Failed to run the installation"
    exit 1
fi

if ! grep 'rycus86/githooks' .git/hooks/pre-commit; then
    echo "! Installation was unsuccessful"
    exit 1
fi

if grep 'rycus86/githooks' /tmp/test094/a/.git/hooks/pre-commit; then
    echo "! Unexpected non-single installation"
    exit 1
fi

git config --global githooks.previous.searchdir /tmp

if ! sh /var/lib/githooks/cli.sh install --global; then
    echo "! Failed to run the global installation"
    exit 1
fi

if ! grep 'rycus86/githooks' /tmp/test094/a/.git/hooks/pre-commit; then
    echo "! Global installation was unsuccessful"
    exit 1
fi

if (cd /tmp/test094/c && sh /var/lib/githooks/cli.sh install); then
    echo "! Single install expected to fail outside a repository"
    exit 1
fi

# revert any changes done by the downloaded install script
if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to run the installation again (1)"
    exit 1
fi

if ! git hooks install; then
    echo "! The Git alias integration failed: single"
    exit 1
fi

# revert any changes done by the downloaded install script
if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to run the installation again (2)"
    exit 1
fi

if ! git hooks install --global; then
    echo "! The Git alias integration failed: global"
    exit 1
fi
