#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.
#
# Version: 1808.091843-d5e832

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
        cat ".githooks/.ignore" >"$ALL_IGNORE_FILE"
        echo >>"$ALL_IGNORE_FILE"
    fi
    if [ -f ".githooks/${HOOK_NAME}/.ignore" ]; then
        cat ".githooks/${HOOK_NAME}/.ignore" >>"$ALL_IGNORE_FILE"
        echo >>"$ALL_IGNORE_FILE"
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

    check_and_execute "$@"
    return $?
}

check_and_execute() {
    if ! [ -f "$HOOK_PATH" ]; then
        return 0
    fi

    TRUSTED_REPO=

    if [ -f ".githooks/trust-all" ]; then
        TRUST_ALL_CONFIG=$(git config --get githooks.trust.all)

        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo "! This repository wants you to trust all current and future hooks without prompting"
            printf "  Do you want to allow running every current and future hooks? [y/N] "
            read -r TRUST_ALL_HOOKS </dev/tty

            if [ "$TRUST_ALL_HOOKS" = "y" ] || [ "$TRUST_ALL_HOOKS" = "Y" ]; then
                git config githooks.trust.all Y
            else
                git config githooks.trust.all N
            fi
        elif [ $? -eq 0 ] && [ "$TRUST_ALL_CONFIG" = "Y" ]; then
            TRUSTED_REPO="Y"
        fi
    fi

    if [ "$TRUSTED_REPO" != "Y" ]; then
        # get hash of the hook contents
        if ! MD5_HASH=$(md5 -r "$HOOK_PATH" 2>/dev/null); then
            MD5_HASH=$(md5sum "$HOOK_PATH" 2>/dev/null)
        fi
        MD5_HASH=$(echo "$MD5_HASH" | awk "{ print \$1 }")
        CURRENT_HASHES=$(grep "$HOOK_PATH" .git/.githooks.checksum 2>/dev/null)
        # check against the previous hash
        if ! echo "$CURRENT_HASHES" | grep -q "$MD5_HASH $HOOK_PATH" >/dev/null 2>&1; then
            if [ -z "$CURRENT_HASHES" ]; then
                MESSAGE="New hook file found"
            elif echo "$CURRENT_HASHES" | grep -q "disabled> $HOOK_PATH" >/dev/null 2>&1; then
                echo "* Skipping disabled $HOOK_PATH"
                echo "  Edit or delete the $(pwd)/.git/.githooks.checksum file to enable it again"
                return 0
            else
                MESSAGE="Hook file changed"
            fi

            echo "? $MESSAGE: $HOOK_PATH"

            if [ "$ACCEPT_CHANGES" = "a" ] || [ "$ACCEPT_CHANGES" = "A" ]; then
                echo "  Already accepted"
            else
                printf "  Do you you accept the changes? (Yes, all, no, disable) [Y/a/n/d] "
                read -r ACCEPT_CHANGES </dev/tty

                if [ "$ACCEPT_CHANGES" = "n" ] || [ "$ACCEPT_CHANGES" = "N" ]; then
                    echo "* Not running $HOOK_FILE"
                    return 0
                fi

                if [ "$ACCEPT_CHANGES" = "d" ] || [ "$ACCEPT_CHANGES" = "D" ]; then
                    echo "* Disabled $HOOK_PATH"
                    echo "  Edit or delete the $(pwd)/.git/.githooks.checksum file to enable it again"

                    echo "disabled> $HOOK_PATH" >>.git/.githooks.checksum
                    return 0
                fi
            fi

            # save the new accepted checksum
            echo "$MD5_HASH $HOOK_PATH" >>.git/.githooks.checksum
        fi
    fi

    if [ -x "$HOOK_PATH" ]; then
        # Run as an executable file
        "$HOOK_PATH" "$@"
        return $?

    elif [ -f "$HOOK_PATH" ]; then
        # Run as a Shell script
        sh "$HOOK_PATH" "$@"
        return $?

    fi

    return 0
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
        REMOTE_URL=$(cd "$SHARED_ROOT" && git config --get remote.origin.url)
        ACTIVE_REPO=$(echo "$SHARED_REPOS_LIST" | grep -o "$REMOTE_URL")
        if [ "$ACTIVE_REPO" != "$REMOTE_URL" ]; then
            continue
        fi

        if [ -d "${SHARED_ROOT}/.githooks" ]; then
            if ! execute_all_hooks_in "${SHARED_ROOT}/.githooks" "$@"; then
                return 1
            fi
        elif [ -d "$SHARED_ROOT" ]; then
            if ! execute_all_hooks_in "$SHARED_ROOT" "$@"; then
                return 1
            fi
        fi
    done

    return 0
}

check_for_updates() {
    if [ "$HOOK_NAME" != "post-commit" ]; then
        return
    fi

    UPDATES_ENABLED=$(git config --global --get githooks.autoupdate.enabled)
    if [ "$UPDATES_ENABLED" != "Y" ]; then
        return
    fi

    LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
    if [ -z "$LAST_UPDATE" ]; then
        LAST_UPDATE=0
    fi

    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - LAST_UPDATE))
    ONE_DAY=86400

    if [ $ELAPSED_TIME -lt $ONE_DAY ]; then
        return # it is not time to update yet
    fi

    git config --global githooks.autoupdate.lastrun "$(date +%s)"

    DOWNLOAD_URL="https://raw.githubusercontent.com/rycus86/githooks/master/install.sh"

    echo "^ Checking for updates ..."

    if curl --version >/dev/null 2>&1; then
        INSTALL_SCRIPT=$(curl -fsSL "$DOWNLOAD_URL" 2>/dev/null)

    elif wget --version >/dev/null 2>&1; then
        INSTALL_SCRIPT=$(wget -O- "$DOWNLOAD_URL" 2>/dev/null)

    else
        echo "! Cannot check for updates - needs either curl or wget"
        return
    fi

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Failed to check for updates"
        return
    fi

    CURRENT_VERSION=$(grep "^# Version: .*" "$0" | sed "s/^# Version: //")
    LATEST_VERSION=$(echo "$INSTALL_SCRIPT" | grep "^# Version: .*" | sed "s/^# Version: //")

    UPDATE_AVAILABLE=$(echo "$CURRENT_VERSION $LATEST_VERSION" | awk "{ print (\$1 >= \$2) }")
    if [ "$UPDATE_AVAILABLE" = "0" ]; then
        echo "* There is a new Githooks update available: Version $LATEST_VERSION"
        printf "    Would you like to install it now? [Y/n] "
        read -r EXECUTE_UPDATE </dev/tty

        if [ -z "$EXECUTE_UPDATE" ] || [ "$EXECUTE_UPDATE" = "y" ] || [ "$EXECUTE_UPDATE" = "Y" ]; then
            if sh -c "$INSTALL_SCRIPT"; then
                return
            fi
        fi

        echo "  If you would like to disable auto-updates, run:"
        echo "    \$ git config --global githooks.autoupdate.enabled N"
    fi
}

HOOK_NAME=$(basename "$0")
HOOK_FOLDER=$(dirname "$0")
ACCEPT_CHANGES=

# Check for updates first, if needed
check_for_updates

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
    if ! process_shared_hooks "$SHARED_HOOKS" "$HOOK_NAME" "$@"; then
        exit 1
    fi
fi

# Check for shared hooks within the current repo
if [ -f "$(pwd)/.githooks/.shared" ]; then
    SHARED_HOOKS=$(grep -E "^[^#].+$" <"$(pwd)/.githooks/.shared")
    if ! process_shared_hooks "$SHARED_HOOKS" "$HOOK_NAME" "$@"; then
        exit 1
    fi
fi

# Execute all hooks in a directory, or a file named as the hook
if ! execute_all_hooks_in "$(pwd)/.githooks" "$@"; then
    exit 1
fi
