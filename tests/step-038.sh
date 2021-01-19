#!/bin/sh
# Test:
#   Remember the start directory for searching existing repos

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p "$GH_TEST_TMP/start/dir" || exit 1

echo "n
y
$GH_TEST_TMP/start
" | "$GH_TEST_BIN/installer" --stdin || exit 1

if [ "$(git config --global --get githooks.previousSearchDir)" != "$GH_TEST_TMP/start" ]; then
    echo "! The search start directory is not recorded"
    exit 1
fi

cd "$GH_TEST_TMP/start/dir" && git init || exit 1

"$GH_TEST_BIN/installer" || exit 1

if ! grep -r 'github.com/rycus86/githooks' "$GH_TEST_TMP/start/dir/.git/hooks"; then
    echo "! Hooks were not installed"
    exit 1
fi
