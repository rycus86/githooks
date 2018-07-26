#!/bin/sh

for STEP in /var/lib/tests/step-*.sh; do
    STEP_NAME=$(basename "$STEP" | sed 's/.sh$//')
    echo "> Executing $STEP_NAME"

    TEST_OUTPUT=$(sh "$STEP" 2>&1)
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! $STEP has failed, output:"
        echo "$TEST_OUTPUT"
        exit 1
    fi

    UNINSTALL_OUTPUT=$(sh /var/lib/githooks/uninstall.sh 2>&1)
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Uninstall failed in $STEP, output:"
        echo "$UNINSTALL_OUTPUT"
        exit 1
    fi
done
