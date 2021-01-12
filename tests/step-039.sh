#!/bin/sh
# Test:
#   Run a install successfully and install run wrappers into the current repo.

mkdir -p /tmp/start/dir && cd /tmp/start/dir || exit 1

mkdir -p /tmp/empty &&
    GIT_TEMPLATE_DIR=/tmp/empty git init || exit 1

if ! "$GITHOOKS_BIN_DIR/installer" --stdin; then
    echo "! Installation failed"
    exit 1
fi

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    OUT=$("$GITHOOKS_BIN_DIR/cli" install 2>&1)
    # shellcheck disable=SC2181
    if [ $? -eq 0 ] || ! echo "$OUT" | grep -q "has no effect"; then
        echo "! Install into current should have failed, because using 'core.hooksPath'"
        exit 1
    fi
else
    if ! "$GITHOOKS_BIN_DIR/cli" install; then
        echo "! Install into current repo should have succeeded"
        exit 1
    fi

    if ! grep -r 'github.com/rycus86/githooks' /tmp/start/dir/.git/hooks; then
        echo "! Hooks were not installed"
        exit 1
    fi
fi
