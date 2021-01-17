#!/bin/sh
# Test:
#   Remember the start directory for searching existing repos

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/start/dir || exit 1

echo 'n
y
/tmp/start
' | "$GITHOOKS_TEST_BIN_DIR/installer" --stdin || exit 1

if [ "$(git config --global --get githooks.previousSearchDir)" != "/tmp/start" ]; then
    echo "! The search start directory is not recorded"
    exit 1
fi

cd /tmp/start/dir && git init || exit 1

"$GITHOOKS_TEST_BIN_DIR/installer" || exit 1

if ! grep -r 'github.com/rycus86/githooks' /tmp/start/dir/.git/hooks; then
    echo "! Hooks were not installed"
    exit 1
fi
