#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.

execute_all_hooks_in() {
    PARENT="$1"
    shift

    # Execute all hooks in a directory, or a file named as the hook
    if [ -d "${PARENT}/${HOOK_NAME}" ]; then
        for HOOK_FILE in "${PARENT}/${HOOK_NAME}"/*; do
            if ! execute_hook "$HOOK_FILE" "$@"; then
                return 1
            fi
        done

    elif [ -f "${PARENT}/${HOOK_NAME}" ]; then
        if ! execute_hook "${PARENT}/${HOOK_NAME}" "$@"; then
            return 1
        fi

    fi

    return 0
}

execute_hook() {
    HOOK_PATH="$1"
    shift

    HOOK_FILENAME=$(basename "$HOOK_PATH")
    IS_IGNORED=""

    # If the ${GITHOOKS_DISABLE} environment variable is set,
    #   do not execute any of the hooks.
    if [ -n "$GITHOOKS_DISABLE" ]; then
        return 0
    fi

    # If there are .ignore files, read the list of patterns to exclude.
    ALL_IGNORE_FILE=$(mktemp)
    if [ -f ".githooks/.ignore" ]; then
        (cat ".githooks/.ignore" ; echo) > "$ALL_IGNORE_FILE"
    fi
    if [ -f ".githooks/${HOOK_NAME}/.ignore" ]; then
        (cat ".githooks/${HOOK_NAME}/.ignore" ; echo) >> "$ALL_IGNORE_FILE"
    fi

    # Check if the filename matches any of the ignored patterns
    while IFS= read -r IGNORED; do
        if [ -z "$IGNORED" ] || [ "$IGNORED" != "${IGNORED#\#}" ]; then
            continue
        fi

        if [ -z "${HOOK_FILENAME##$IGNORED}" ]; then
            IS_IGNORED="y"
            break
        fi
    done <"$ALL_IGNORE_FILE"

    # Remove the temporary file
    rm -f "$ALL_IGNORE_FILE"

    # If this file is ignored, stop
    if [ -n "$IS_IGNORED" ]; then
        return 0
    fi

    # Assume success by default
    RESULT=0

    if [ -x "$HOOK_PATH" ]; then
        # Run as an executable file
        "$HOOK_PATH" "$@"
        RESULT=$?

    elif [ -f "$HOOK_PATH" ]; then
        # Run as a Shell script
        sh "$HOOK_PATH" "$@"
        RESULT=$?
        
    fi

    return $RESULT
}

process_shared_hooks() {
    SHARED_REPOS_LIST="$1"
    shift
    HOOK_NAME="$1"
    shift

    # run an init/update if we are after a "git pull" or triggered manually
    if [ "$HOOK_NAME" = "post-merge" ] || [ "$HOOK_NAME" = ".githooks.shared.trigger" ]; then
        # split on comma and newline
        IFS=",
        "

        for SHARED_REPO in $SHARED_REPOS_LIST; do
            mkdir -p ~/.githooks.shared

            NORMALIZED_NAME=$(echo "$SHARED_REPO" |
                sed -E "s#.*[:/](.+/.+)\\.git#\\1#" |
                sed -E "s/[^a-zA-Z0-9]/_/g")

            if [ -d ~/.githooks.shared/"$NORMALIZED_NAME"/.git ]; then
                echo "* Updating shared hooks from: $SHARED_REPO"
                PULL_OUTPUT=$(cd ~/.githooks.shared/"$NORMALIZED_NAME" && git pull 2>&1)
                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Update failed, git pull output:"
                    echo "$PULL_OUTPUT"
                fi
            else
                echo "* Retrieving shared hooks from: $SHARED_REPO"
                CLONE_OUTPUT=$(cd ~/.githooks.shared && git clone "$SHARED_REPO" "$NORMALIZED_NAME" 2>&1)
                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Clone failed, git clone output:"
                    echo "$CLONE_OUTPUT"
                fi
            fi
        done

        unset IFS
    fi

    for SHARED_ROOT in ~/.githooks.shared/*; do
        REMOTE_URL=$(cd "$SHARED_ROOT" && git remote get-url origin)
        ACTIVE_REPO=$(echo "$SHARED_REPOS_LIST" | grep -o "$REMOTE_URL")
        if [ "$ACTIVE_REPO" != "$REMOTE_URL" ]; then
            continue
        fi
        
        if [ -d "${SHARED_ROOT}/.githooks" ]; then
            execute_all_hooks_in "${SHARED_ROOT}/.githooks" "$@"
        elif [ -d "$SHARED_ROOT" ]; then
            execute_all_hooks_in "$SHARED_ROOT" "$@"
        fi
    done
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

# Check for shared hooks set globally
SHARED_HOOKS=$(git config --global --get githooks.shared)

if [ -n "$SHARED_HOOKS" ]; then
    process_shared_hooks "$SHARED_HOOKS" "$HOOK_NAME" "$@"
fi

# Check for shared hooks within the current repo
if [ -f "$(pwd)/.githooks/.shared" ]; then
    SHARED_HOOKS=$(grep -E "^[^#].+$" < "$(pwd)/.githooks/.shared")
    process_shared_hooks "$SHARED_HOOKS" "$HOOK_NAME" "$@"
fi

# Execute all hooks in a directory, or a file named as the hook
if ! execute_all_hooks_in "$(pwd)/.githooks" "$@"; then
    exit 1
fi
