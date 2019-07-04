#!/bin/sh
# Test:
#   Cli tool: add/update README

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

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/not/a/git/repo && cd /tmp/not/a/git/repo || exit 1

if sh /var/lib/githooks/cli.sh readme add; then
    echo "! Expected to fail"
    exit 1
fi

mkdir -p /tmp/test080 && cd /tmp/test080 && git init || exit 1

sh /var/lib/githooks/cli.sh readme update &&
    [ -f .githooks/README.md ] ||
    exit 1

if sh /var/lib/githooks/cli.sh readme add; then
    echo "! Expected to fail"
    exit 1
fi

# Check the Git alias
rm -f .githooks/README.md &&
    git hooks readme add &&
    [ -f .githooks/README.md ] ||
    exit 1
