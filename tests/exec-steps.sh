#!/bin/sh

FAILED=0

for STEP in /var/lib/tests/step-*.sh; do
    STEP_NAME=$(basename "$STEP" | sed 's/.sh$//')
    STEP_DESC=$(head -3 "$STEP" | tail -1 | sed 's/#\s*//')

    echo "> Executing $STEP_NAME"
    echo "  :: $STEP_DESC"

    mkdir -p /usr/share/git-core/templates/hooks
    rm -rf /usr/share/git-core/templates/hooks/*

    TEST_OUTPUT=$(sh "$STEP" 2>&1)
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        FAILURE=$(echo "$TEST_OUTPUT" | tail -1)
        echo "! $STEP has failed ($FAILURE), output:"
        echo "$TEST_OUTPUT"
        FAILED=$((FAILED + 1))
    fi

    mkdir -p /usr/share/git-core/templates/hooks

    UNINSTALL_OUTPUT=$(sh /var/lib/githooks/uninstall.sh 2>&1)
    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Uninstall failed in $STEP, output:"
        echo "$UNINSTALL_OUTPUT"
        FAILED=$((FAILED + 1))
    fi

    git config --global --unset init.templateDir

    echo

done

if [ $FAILED -ne 0 ]; then
    echo "There were $FAILED test failure(s)"
    echo
    exit 1
fi
