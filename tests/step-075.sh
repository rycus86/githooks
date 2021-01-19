#!/bin/sh
# Test:
#   Uninstall: start directory options for existing repos

mkdir -p "$GH_TEST_TMP/test074/.githooks/pre-commit" &&
    echo 'echo "Hello"' >"$GH_TEST_TMP/test074/.githooks/pre-commit/testing" &&
    cd "$GH_TEST_TMP/test074" &&
    git init ||
    exit 1

echo "y
y
$GH_TEST_TMP
" | "$GH_TEST_BIN/installer" --stdin || exit 1

echo 'y

' | "$GH_TEST_BIN/uninstaller" --stdin || exit 2

echo 'y
/not/found
' | "$GH_TEST_BIN/uninstaller" --stdin

# shellcheck disable=SC2181
if [ $? -eq 0 ]; then
    echo "! Uninstall unexpectedly finished"
    exit 1
fi
