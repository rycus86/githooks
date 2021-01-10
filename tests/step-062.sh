#!/bin/sh
# Test:
#   Cli tool: run update check

"$GITHOOKS_BIN_DIR/installer" --stdin || exit 1

mkdir -p /tmp/test062 &&
    cd /tmp/test062 &&
    git init ||
    exit 1

OUT=$("$GITHOOKS_INSTALL_BIN_DIR/cli" update --no)
# shellcheck disable=SC2181
if [ $? -ne 0 ] || ! echo "$OUT" | grep -qi "is at the latest version"; then
    echo "! Failed to run the update with --no"
    echo "$OUT"
    exit 1
fi

# Reset to trigger update
if ! (cd ~/.githooks/release && git reset --hard HEAD~1 >/dev/null); then
    echo "! Could not reset master to trigger update."
    exit 1
fi

OUT=$("$GITHOOKS_INSTALL_BIN_DIR/cli" update --no)
# shellcheck disable=SC2181
if [ $? -ne 0 ] || ! echo "$OUT" | grep -qi "update declined"; then
    echo "! Failed to run the update with --no"
    echo "$OUT"
    exit 1
fi
