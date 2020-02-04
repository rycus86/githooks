#!/bin/sh
if [ -n "$TEST_STEP" ]; then
    STEPS_TO_RUN="step-${TEST_STEP}.sh"
else
    STEPS_TO_RUN="step-*"
fi

ROOT_DIR="C:/Program Files"
mkdir -p "$ROOT_DIR/githooks" || true
cp base-template.sh "$ROOT_DIR/githooks"/ || exit 1
cp install.sh "$ROOT_DIR/githooks"/ || exit 1
cp uninstall.sh "$ROOT_DIR/githooks"/ || exit 1
cp cli.sh "$ROOT_DIR/githooks"/ || exit 1
cp examples "$ROOT_DIR/githooks"/ || exit 1

GITHOOKS_TESTS="$ROOT_DIR/tests"

git config --global user.email "githook@test.com" || exit 2
git config --global user.name "Githook Tests" || exit 2

cp tests/exec-steps.sh "$GITHOOKS_TESTS"/ || exit 3
# shellcheck disable=SC2086
cp tests/$STEPS_TO_RUN "$GITHOOKS_TESTS"/ || exit 3

# Do not use the terminal in tests
sed -i 's|</dev/tty||g' "$ROOT_DIR"/install.sh || exit 4

# We overwrite the download to use the current install.sh !
sed -i -E 's|download_file.*"install.sh"|cp -f /var/lib/githooks/install.sh|' "$ROOT_DIR"/install.sh

# Change the base template so we can pass in the hook name and accept flags
# shellcheck disable=SC2016
sed -i -E 's|HOOK_NAME=.*|HOOK_NAME=\${HOOK_NAME:-\$(basename "\$0")}|' "$ROOT_DIR"base-template.sh &&
    sed -i -E 's|echo.*Hook not run inside a git repository.*|CURRENT_GIT_DIR=".git"|' /var/lib/githooks/base-template.sh /var/lib/githooks/install.sh &&
    sed -i -E 's|HOOK_FOLDER=.*|HOOK_FOLDER=\${HOOK_FOLDER:-\$(dirname "\$0")}|' "$ROOT_DIR"/base-template.sh &&
    sed -i 's|ACCEPT_CHANGES=|ACCEPT_CHANGES=\${ACCEPT_CHANGES}|' "$ROOT_DIR"/base-template.sh &&
    sed -i 's|read -r "\$VARIABLE"|eval "\$VARIABLE=\$\$(eval echo "\$VARIABLE")" # disabled for tests: read -r "\$VARIABLE"|' "$ROOT_DIR"/base-template.sh || exit 5

if [ -n "${EXTRA_INSTALL_ARGS}" ]; then
    sed -i "s|sh \"$ROOT_DIR\"/install.sh|sh \"$ROOT_DIR\"/install.sh \${EXTRA_INSTALL_ARGS}|g" /var/lib/tests/step-* || exit 6
    sed -i -E "s|sh -c (.*) -- |sh -c \1 -- \${EXTRA_INSTALL_ARGS} |g" /var/lib/tests/step-* || exit 7
fi

# Patch all paths to use windows base path
sed -i -E "s|([^\"])/var/lib/|\1\"$ROOT_DIR\"/|g" "$ROOT_DIR"/tests/exec-tests.sh "$ROOT_DIR"/tests/step-* || exit 7
sed -i -E "s|\"/var/lib/|\"$ROOT_DIR/|g" "$ROOT_DIR"/tests/exec-tests.sh "$ROOT_DIR"/tests/step-* || exit 7

sh "$ROOT_DIR"/tests/exec-steps.sh
