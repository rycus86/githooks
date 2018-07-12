#!/bin/sh
# Base githooks template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.

HOOK_NAME=$(basename "$0")
HOOK_FOLDER=$(dirname "$0")

# Execute the old hook if we moved it when installing our hooks.
if [ -x "${HOOK_FOLDER}/${HOOK_NAME}.replaced.githook" ]; then
	ABSOLUTE_FOLDER=$(cd "${HOOK_FOLDER}" && pwd)
    "${ABSOLUTE_FOLDER}/${HOOK_NAME}.replaced.githook" "$@"
fi

if [ -d ".githooks/${HOOK_NAME}" ]; then
    # If there is a directory like .githooks/pre-commit,
	#   then for files like .githooks/pre-commit/lint
    for HOOK_FILE in .githooks/"${HOOK_NAME}"/*; do
        # Either execute directly or as a Shell script
        if [ -x "$HOOK_FILE" ]; then
            "$(pwd)/$HOOK_FILE" "$@"
        elif [ -f "$HOOK_FILE" ]; then
            sh "$HOOK_FILE" "$@"
        fi
    done

elif [ -x ".githooks/${HOOK_NAME}" ]; then
    # Execute the file directly
    eval "$(pwd)/.githooks/${HOOK_NAME}" "$@"

elif [ -f ".githooks/${HOOK_NAME}" ]; then
    # Execute as a Shell script
    sh ".githooks/${HOOK_NAME}" "$@"

fi