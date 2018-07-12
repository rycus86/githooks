#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.

execute_hook() {
    HOOK_PATH="$1"
    shift

    RESULT=0

    if [ -x "$HOOK_PATH" ]; then
        "$HOOK_PATH" "$@"
        RESULT=$?

    elif [ -f "$HOOK_PATH" ]; then
        sh "$HOOK_PATH" "$@"
        
        RESULT=$?
    fi

    return $RESULT
}

HOOK_NAME=$(basename "$0")
HOOK_FOLDER=$(dirname "$0")

# Execute the old hook if we moved it when installing our hooks.
if [ -x "${HOOK_FOLDER}/${HOOK_NAME}.replaced.githook" ]; then
	ABSOLUTE_FOLDER=$(cd "${HOOK_FOLDER}" && pwd)

    if ! execute_hook "${ABSOLUTE_FOLDER}/${HOOK_NAME}.replaced.githook" "$@"; then
        exit 1
    fi
fi

if [ -d ".githooks/${HOOK_NAME}" ]; then
    # If there is a directory like .githooks/pre-commit,
	#   then for files like .githooks/pre-commit/lint
    for HOOK_FILE in .githooks/"${HOOK_NAME}"/*; do
        if ! execute_hook "$(pwd)/$HOOK_FILE" "$@"; then
            exit 1
        fi
    done

elif [ -f ".githooks/${HOOK_NAME}" ]; then
    if ! execute_hook ".githooks/${HOOK_NAME}" "$@"; then
        exit 1
    fi

fi