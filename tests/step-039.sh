#!/bin/sh
# Test:
#   Run a single-repo install successfully

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/start/dir && cd /tmp/start/dir || exit 1

mkdir -p /tmp/empty &&
    GIT_TEMPLATE_DIR=/tmp/empty git init || exit 1

git config --local githooks.single.install "Y"
OUT=$(sh /var/lib/githooks/install.sh --single 2>&1)
if ! echo "$OUT" | grep -iq "DEPRECATION WARNING: Single install"; then
    echo "! Expected installation to fail because of single install flag: $OUT"
    exit 1
fi
git config --local --unset githooks.single.install

if ! sh /var/lib/githooks/install.sh --single; then
    echo "! Installation failed"
    exit 1
fi

if ! grep -r 'github.com/rycus86/githooks' /tmp/start/dir/.git/hooks; then
    echo "! Hooks were not installed"
    exit 1
fi
