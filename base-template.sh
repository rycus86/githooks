#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.
#
# Legacy version number. Not used anymore, but old installs read it.
# Version: 9912.310000-000000

#####################################################
# Execute the current hook,
#   that in turn executes the hooks in the repo.
#
# Returns:
#   0 when successfully finished, 1 otherwise
#####################################################
process_git_hook() {

    set_main_variables "$1" || return 1
    shift 1

    register_installation_if_needed

    if are_githooks_disabled; then
        execute_lfs_hook_if_appropriate "$@" || return 1
        execute_old_hook_if_available "$@" || return 1
        return
    fi

    export_staged_files
    check_for_updates_if_needed
    execute_lfs_hook_if_appropriate "$@" || return 1
    execute_old_hook_if_available "$@" || return 1
    execute_all_shared_hooks "$@" || return 1
    execute_all_hooks_in "$(pwd)/.githooks" "$@" || return 1
}

#####################################################
# Checks if Githooks is completely disabled
#   for the current repository or globally.
#   This can be done with Git config or using
#   the ${GITHOOKS_DISABLE} environment variable.
#
# Returns:
#   0 when disabled, 1 otherwise
#####################################################
are_githooks_disabled() {
    [ -n "$GITHOOKS_DISABLE" ] && return 0

    GITHOOKS_CONFIG_DISABLE=$(git config --get githooks.disable)
    if [ "$GITHOOKS_CONFIG_DISABLE" = "true" ] ||
        [ "$GITHOOKS_CONFIG_DISABLE" = "y" ] ||    # Legacy
        [ "$GITHOOKS_CONFIG_DISABLE" = "Y" ]; then # Legacy
        return 0
    fi

    return 1
}

#####################################################
# Sets the ${INSTALL_DIR} variable.
#
# Returns: None
#####################################################
load_install_dir() {

    INSTALL_DIR=$(git config --global --get githooks.installDir)

    if [ -z "${INSTALL_DIR}" ]; then
        # install dir not defined, use default
        INSTALL_DIR=~/".githooks"
    elif [ ! -d "$INSTALL_DIR" ]; then
        echo "! Githooks installation is corrupt! " >&2
        echo "  Install directory at \`$INSTALL_DIR\` is missing." >&2
        INSTALL_DIR=~/".githooks"
        echo "  Falling back to default directory at \`$INSTALL_DIR\`" >&2
        echo "  Please run the Githooks install script again to fix it." >&2
    fi

    GITHOOKS_CLONE_DIR="$INSTALL_DIR/release"
}

#####################################################
# Set up the main variables that
#   we will throughout the hook.
#
# Sets the ${HOOK_NAME} variable
# Sets the ${HOOK_FOLDER} variable
# Resets the ${ACCEPT_CHANGES} variable
# Sets the ${CURRENT_GIT_DIR} variable
#
# Returns: 0 if succesful, 1 otherwise
#####################################################
set_main_variables() {
    HOOK_NAME="$(basename "$1")"
    HOOK_FOLDER="$(dirname "$1")"

    ACCEPT_CHANGES=

    CURRENT_GIT_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
    if [ ! -d "${CURRENT_GIT_DIR}" ]; then
        echo "! Hook not run inside a git repository" >&2
        return 1
    fi

    load_install_dir

    # Global IFS for loops
    IFS_NEWLINE="
"

    # Fail if the shared root is not available (if enabled)
    FAIL_ON_NOT_EXISTING_SHARED_HOOK=$(git config --get githooks.failOnNonExistingSharedHooks)

    return 0
}

############################################################
# We register this repository in the global install list
# if it is not registered.
#
# Returns: None
############################################################
register_installation_if_needed() {
    if ! git config --local githooks.registered >/dev/null 2>&1 &&
        [ ! -d "$(git config core.hooksPath)" ]; then
        register_repo "$CURRENT_GIT_DIR"
    fi
}

############################################################
# Adds the repository to the global list of all repos which
#   use githooks
#
# Returns: None
############################################################
register_repo() {
    CURRENT_REPO="$(cd "$1" && pwd)"
    LIST="$INSTALL_DIR/registered"

    # Remove
    if [ -f "$LIST" ]; then
        TEMP_FILE=$(mktemp)
        CURRENT_ESCAPED=$(echo "$CURRENT_REPO" | sed "s@/@\\\\\/@g")
        sed "/$CURRENT_ESCAPED/d" "$LIST" >"$TEMP_FILE"
        mv -f "$TEMP_FILE" "$LIST"
    else
        # Create folder
        PARENT_DIR=$(dirname "$LIST")
        if [ ! -d "$PARENT_DIR" ]; then
            mkdir -p "$PARENT_DIR" >/dev/null 2>&1
        fi
    fi

    # Add at the bottom
    echo "$CURRENT_REPO" >>"$LIST"
    # Mark this repo as registered
    git config --local githooks.registered "true"
}

#####################################################
# Exports the list of staged, changed files
#   when available, so hooks can use it if
#   they want to.
#
# Sets the ${STAGED_FILES} variable
#
# Returns:
#   None
#####################################################
export_staged_files() {
    if ! echo "pre-commit prepare-commit-msg commit-msg" | grep -q "$HOOK_NAME" 2>/dev/null; then
        return # we only want to do this for commit related events
    fi

    CHANGED_FILES=$(git diff --cached --diff-filter=ACMR --name-only)

    # shellcheck disable=SC2181
    if [ $? -eq 0 ]; then
        export STAGED_FILES="$CHANGED_FILES"
    fi
}

#####################################################
# Executes the old hook if we moved one
#   while installing our hooks.
#
# Returns:
#   1 if the old hook failed, 0 otherwise
#####################################################
execute_old_hook_if_available() {
    if [ -x "${HOOK_FOLDER}/${HOOK_NAME}.replaced.githook" ]; then
        ABSOLUTE_FOLDER=$(cd "${HOOK_FOLDER}" && pwd)
        execute_hook "${ABSOLUTE_FOLDER}/${HOOK_NAME}.replaced.githook" "$@" || return 1
    fi
}

#####################################################
# Executes a Git LFS hook if `git-lfs`
#   is available and the hook type is one that
#   Git LFS is known to handle.
#
# Returns:
#   1 if the old hook failed, 0 otherwise
#####################################################
execute_lfs_hook_if_appropriate() {
    CAN_RUN_LFS_HOOK="false"
    [ "$HOOK_NAME" = "post-checkout" ] && CAN_RUN_LFS_HOOK="true"
    [ "$HOOK_NAME" = "post-commit" ] && CAN_RUN_LFS_HOOK="true"
    [ "$HOOK_NAME" = "post-merge" ] && CAN_RUN_LFS_HOOK="true"
    [ "$HOOK_NAME" = "pre-push" ] && CAN_RUN_LFS_HOOK="true"

    # not an event LFS would care about
    [ "$CAN_RUN_LFS_HOOK" = "false" ] && return

    # do we have Git LFS installed
    GIT_LFS_AVAILABLE="false"
    command -v git-lfs >/dev/null 2>&1 && GIT_LFS_AVAILABLE="true"

    # do we require LFS support in this repository
    REQUIRES_LFS_SUPPORT="false"
    [ -f "$(pwd)/.githooks/.lfs-required" ] && REQUIRES_LFS_SUPPORT="true"

    if [ "$GIT_LFS_AVAILABLE" = "true" ]; then
        git lfs "$HOOK_NAME" "$@" || return 1
    elif [ "$REQUIRES_LFS_SUPPORT" = "true" ]; then
        echo "! This repository requires Git LFS, but \`git-lfs\` was not found on your PATH." >&2
        echo "  If you no longer want to use Git LFS, remove the \`.githooks/.lfs-required\` file." >&2
        return 1
    fi
}

#####################################################
# Check if we have shared hooks set up
#   within the current repository,
#   and execute all of them if we do.
#
# Returns:
#   1 if the hooks fail, 0 otherwise
#####################################################
execute_all_shared_hooks() {
    # track all executed hooks, to reject double execution
    EXECUTED_SHARED_HOOKS=""

    if [ -f "$(pwd)/.githooks/.shared" ]; then
        SHARED_HOOKS=$(grep -E "^[^#\n\r ].*$" <"$(pwd)/.githooks/.shared")
        process_shared_hooks --shared "$SHARED_HOOKS" "$@" || return 1
    fi

    SHARED_HOOKS=$(git config --local --get-all githooks.shared)
    if [ -n "$SHARED_HOOKS" ]; then
        process_shared_hooks --local "$SHARED_HOOKS" "$@" || return 1
    fi

    SHARED_HOOKS=$(git config --global --get-all githooks.shared)
    if [ -n "$SHARED_HOOKS" ]; then
        process_shared_hooks --global "$SHARED_HOOKS" "$@" || return 1
    fi
}

#####################################################
# Executes all hook files or scripts in the
#   directory passed in on the first argument.
#
# Returns:
#   1 if the hooks fail, 0 otherwise
#####################################################
execute_all_hooks_in() {
    PARENT="$1"
    shift

    # Execute all hooks in a directory, or a file named as the hook
    if [ -d "${PARENT}/${HOOK_NAME}" ]; then
        for HOOK_FILE in "${PARENT}/${HOOK_NAME}"/*; do
            execute_hook "$HOOK_FILE" "$@" || return 1
        done

    elif [ -f "${PARENT}/${HOOK_NAME}" ]; then
        execute_hook "${PARENT}/${HOOK_NAME}" "$@" || return 1

    fi
}

#####################################################
# Executes a single hook file or script
#   at the path passed in on the first argument.
#
# Returns:
#   0 if the hook is ignored,
#     otherwise the exit code of the hook
#####################################################
execute_hook() {
    HOOK_PATH="$1"
    shift

    # stop if the file does not exist
    [ -f "$HOOK_PATH" ] || return 0

    # stop if the file is ignored
    is_file_ignored && return 0

    check_and_execute_hook "$@"
    return $?
}

#####################################################
# Checks if the hook file at ${HOOK_PATH}
#   is ignored and should not be executed.
#
# Returns:
#   0 if ignored, 1 otherwise
#####################################################
is_file_ignored() {
    HOOK_FILENAME=$(basename "$HOOK_PATH")
    IS_IGNORED=""

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

        # shellcheck disable=SC2295
        if [ -z "${HOOK_FILENAME##$IGNORED}" ]; then
            IS_IGNORED="y"
            break
        fi
    done <"$ALL_IGNORE_FILE"

    # Remove the temporary file
    rm -f "$ALL_IGNORE_FILE"

    if [ -n "$IS_IGNORED" ]; then
        return 0
    else
        return 1
    fi
}

#####################################################
# Performs the necessary checks,
#   and asks for confirmation if needed,
#   then executes a hook if all good and approved.
#
# Returns:
#   0 when skipped,
#   otherwise the exit code of the hook
#####################################################
check_and_execute_hook() {
    if ! is_trusted_repo; then
        execute_opt_in_checks || return 0
    fi

    run_hook_file "$@"
    return $?
}

#####################################################
# Returns and/or sets whether the current
#   local repository is a trusted repository or not.
#
# Returns:
#   0 when it is a trusted repository, 1 otherwise
#####################################################
is_trusted_repo() {
    if [ -f "${PARENT}/trust-all" ]; then

        if [ -n "$SHARED_HOOKS_TYPE" ]; then
            TRUST_ALL_SHARED_CONFIG=$(git config --global --get githooks.trust.all)
            if [ "$TRUST_ALL_SHARED_CONFIG" = "Y" ]; then
                return 0
            else
                return 1
            fi
        else
            TRUST_ALL_CONFIG=$(git config --local --get githooks.trust.all)
            TRUST_ALL_RESULT=$?

            # shellcheck disable=SC2181
            if [ $TRUST_ALL_RESULT -ne 0 ]; then
                MESSAGE="$(printf "%s\n%s" "! This repository wants you to trust all current and future hooks without prompting" "  Do you want to allow running every current and future hooks?")"

                show_prompt TRUST_ALL_HOOKS "$MESSAGE" "(yes, No)" "y/N" "Yes" "No"

                if [ "$TRUST_ALL_HOOKS" = "y" ] || [ "$TRUST_ALL_HOOKS" = "Y" ]; then
                    git config githooks.trust.all Y
                    return 0
                else
                    git config githooks.trust.all N
                    return 1
                fi
            elif [ $TRUST_ALL_RESULT -eq 0 ] && [ "$TRUST_ALL_CONFIG" = "Y" ]; then
                return 0
            fi
        fi
    fi
 
    return 1
}



#####################################################
# Performs checks for new and changed hooks,
#   and prompts the user for approval if needed.
#
# Returns:
#   0 when approved to run the hook, 1 otherwise
#####################################################
execute_opt_in_checks() {
    # get hash of the hook contents
    SHA_HASH=$(git hash-object "$HOOK_PATH" 2>/dev/null)
    CURRENT_HASHES=$(grep "$HOOK_PATH" "$CURRENT_GIT_DIR/.githooks.checksum" 2>/dev/null)

    # check against the previous hash
    if echo "$CURRENT_HASHES" | grep -q "disabled> $HOOK_PATH" >/dev/null 2>&1; then
        if should_output_skipping_disabled_hook "$HOOK_PATH"; then
            echo "* Skipping disabled $HOOK_PATH" >&2
            echo "  Use \`git hooks enable $HOOK_NAME $(basename "$HOOK_PATH")\` to enable it again" >&2
            echo "  Alternatively, edit or delete the $(pwd)/$CURRENT_GIT_DIR/.githooks.checksum file to enable it again" >&2
            record_skipping_disabled_hook_time "$HOOK_PATH"
        fi
        return 1

    elif ! echo "$CURRENT_HASHES" | grep -q "$SHA_HASH $HOOK_PATH" >/dev/null 2>&1; then
        if [ -z "$CURRENT_HASHES" ]; then
            MESSAGE="New hook file found"
        else
            MESSAGE="Hook file changed"
        fi

        if [ "$ACCEPT_CHANGES" = "a" ] || [ "$ACCEPT_CHANGES" = "A" ]; then
            echo "? $MESSAGE: $HOOK_PATH" >&2
            echo " Already accepted" >&2
        else
            MESSAGE="$(printf "%s\n%s" "$MESSAGE: $HOOK_PATH" "  Do you accept the changes?")"
            show_prompt ACCEPT_CHANGES "? $MESSAGE" "(Yes, all, no, disable)" "Y/a/n/d" "Yes" "All" "No" "Disable"

            if [ "$ACCEPT_CHANGES" = "n" ] || [ "$ACCEPT_CHANGES" = "N" ]; then
                echo "* Not running $HOOK_FILE" >&2
                return 1
            fi

            if [ "$ACCEPT_CHANGES" = "d" ] || [ "$ACCEPT_CHANGES" = "D" ]; then
                echo "* Disabled $HOOK_PATH" >&2
                echo "  Use \`git hooks enable $HOOK_NAME $(basename "$HOOK_PATH")\` to enable it again" >&2
                echo "  Alternatively, edit or delete the $(pwd)/$CURRENT_GIT_DIR/.githooks.checksum file to enable it again" >&2

                echo "disabled> $HOOK_PATH" >>"$CURRENT_GIT_DIR/.githooks.checksum"
                return 1
            fi
        fi

        # save the new accepted checksum
        echo "$SHA_HASH $HOOK_PATH" >>"$CURRENT_GIT_DIR/.githooks.checksum"
    fi
}

#####################################################
# Returns whether the fact that a disabled hook is
#   being skipped should be written to the output
#   (once a day) or not.
#
# Returns:
#   0 when the output should be written
#   1 if the output should not be written
#####################################################
should_output_skipping_disabled_hook() {
    HOOK_PATH="$1"
    LAST_UPDATE=$(grep "$HOOK_PATH" "$CURRENT_GIT_DIR/.githooks.skip.output.dates" | sed -E "s/([^ ]+) .*/\1/")
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - LAST_UPDATE))
    ONE_DAY=86400

    if [ $ELAPSED_TIME -lt $ONE_DAY ]; then
        return 1 # it is not time to write it again yet
    fi
}

#####################################################
# Saves the last output date of the fact a given
#   disabled hook was skipped.
#####################################################
record_skipping_disabled_hook_time() {
    HOOK_PATH="$1"
    OUTPUT_DATES=$(cat "$CURRENT_GIT_DIR/.githooks.skip.output.dates")

    # reset the file
    echo "# Last output date disabled hooks being skipped was printed" >"$CURRENT_GIT_DIR/.githooks.skip.output.dates"

    IFS="$IFS_NEWLINE"
    for LINE in ${OUTPUT_DATES}; do
        unset IFS

        if echo "$LINE" | grep -qv "$HOOK_PATH"; then
            echo "$LINE" >>"$CURRENT_GIT_DIR/.githooks.skip.output.dates"
        fi

        IFS="$IFS_NEWLINE"
    done

    echo "$(date +%s) $HOOK_PATH" >>"$CURRENT_GIT_DIR/.githooks.skip.output.dates"
}

#####################################################
# Executes the current hook file.
#
# Returns:
#   0 when not found,
#     otherwise the exit code of the hook
#####################################################
run_hook_file() {
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

#####################################################
# Update and execute the shared hooks on
#   the list passed in on the first argument.
#
# Returns:
#   1 in case a hook fails, 0 otherwise
#####################################################
process_shared_hooks() {
    SHARED_HOOKS_TYPE="$1"
    SHARED_REPOS_LIST="$2"
    shift 2

    update_shared_hooks_if_appropriate "$@"
    execute_shared_hooks "$@" || return 1
}

#####################################################
# Check if `$1` is not a supported git clone url and
#   is treated as a local path to a repository.
#   See `https://tools.ietf.org/html/rfc3986#appendix-B`

# Returns: 0 if it is a local path, 1 otherwise
#####################################################
is_local_path() {
    if echo "$1" | grep -Eq "^[^:/?#]+://" ||  # its a <scheme>://
        echo "$1" | grep -Eq "^.+@.+:.+"; then # or its a short scp syntax
        return 1
    fi
    return 0
}

#####################################################
# Check if url `$1` is a local url, e.g `file://`.
#
# Returns: 0 if it is a local url, 1 otherwise
#####################################################
is_local_url() {
    if echo "$1" | grep -iEq "^\s*file://"; then
        return 0
    fi
    return 1
}

#####################################################
# Sets the `SHARED_ROOT` for the shared hook repo
#    url `$1` and sets
#   `SHARED_REPO_IS_CLONED` to `true` and its
#   `SHARED_REPO_CLONE_URL` if is needs to get
#    cloned and `SHARED_REPO_IS_LOCAL` to `true`
#    if `$1` points to to a local path.
#
# Returns:
#   none
#####################################################
set_shared_root() {

    SHARED_ROOT=""
    SHARED_REPO_CLONE_URL=""
    SHARED_REPO_CLONE_BRANCH=""
    SHARED_REPO_IS_LOCAL="false"
    SHARED_REPO_IS_CLONED="true"
    DO_SPLIT="true"

    if is_local_path "$1"; then
        SHARED_REPO_IS_LOCAL="true"

        if is_bare_repo "$1"; then
            DO_SPLIT="false"
        else
            # We have a local path to a non-bare repo
            SHARED_REPO_IS_CLONED="false"
            SHARED_ROOT="$1"
        fi
    elif is_local_url "$1"; then
        SHARED_REPO_IS_LOCAL="true"
    fi

    if [ "$SHARED_REPO_IS_CLONED" = "true" ]; then
        # Here we now have a supported Git URL or
        # a local bare-repo `<localpath>`

        # Split "...@(.*)"
        if [ "$DO_SPLIT" = "true" ] && echo "$1" | grep -q "@"; then
            SHARED_REPO_CLONE_URL="$(echo "$1" | sed -E "s|^(.+)@.+$|\\1|")"
            SHARED_REPO_CLONE_BRANCH="$(echo "$1" | sed -E "s|^.+@(.+)$|\\1|")"
        else
            SHARED_REPO_CLONE_URL="$1"
            SHARED_REPO_CLONE_BRANCH=""
        fi

        # Double-check what we did above
        if echo "$SHARED_REPO_CLONE_BRANCH" | grep -q ":"; then
            # the branch name had a ":" so it was probably not a branch name
            SHARED_REPO_CLONE_URL="${SHARED_REPO_CLONE_URL}@${SHARED_REPO_CLONE_BRANCH}"
            SHARED_REPO_CLONE_BRANCH=""

        elif echo "$SHARED_REPO_CLONE_URL" | grep -qE ".*://[^/]+$"; then
            # the clone URL is something starting with a protocol then no path parts, then we probably split at the wrong place
            SHARED_REPO_CLONE_URL="${SHARED_REPO_CLONE_URL}@${SHARED_REPO_CLONE_BRANCH}"
            SHARED_REPO_CLONE_BRANCH=""
        fi

        # Define the shared clone folder
        SHA_HASH=$(echo "$1" | git hash-object --stdin 2>/dev/null)
        NAME=$(echo "$1" | tail -c 48 | sed -E "s/[^a-zA-Z0-9]/-/g")
        SHARED_ROOT="$INSTALL_DIR/shared/$SHA_HASH-$NAME"
    fi
}

#####################################################
# Update the shared hooks that are on the
#   ${SHARED_REPOS_LIST} variable.
#
# Returns:
#   0 when successfully finished, 1 otherwise
#####################################################
update_shared_hooks_if_appropriate() {
    # run an init/update if we are after a "git pull" or triggered manually
    GIT_NULL_REF="0000000000000000000000000000000000000000"

    RUN_UPDATE="false"

    [ "$HOOK_NAME" = "post-merge" ] && RUN_UPDATE="true"
    [ "$HOOK_NAME" = "post-checkout" ] && [ "$1" = "$GIT_NULL_REF" ] && RUN_UPDATE="true"
    git config --get-all githooks.sharedHooksUpdateTriggers | grep -q "$HOOK_NAME" && RUN_UPDATE="true"

    if [ "$RUN_UPDATE" = "true" ]; then

        IFS="$IFS_NEWLINE"
        for SHARED_REPO in $SHARED_REPOS_LIST; do
            unset IFS

            set_shared_root "$SHARED_REPO"

            if [ "$SHARED_REPO_IS_CLONED" != "true" ]; then
                # Non-cloned roots are ignored
                continue
            elif [ "$SHARED_HOOKS_TYPE" = "--shared" ] &&
                [ "$SHARED_REPO_IS_LOCAL" = "true" ]; then
                echo "! Warning: Shared hooks in \`.githooks/.shared\` contain a local path" >&2
                echo "  \`$SHARED_REPO\`" >&2
                echo "  which is forbidden. Update will be skipped." >&2
                echo "" >&2
                echo "  You can only have local paths for shared hooks defined" >&2
                echo "  in the local or global Git configuration." >&2
                echo "" >&2
                echo "  This can be achieved by running" >&2
                echo "    \$ git hooks shared add [--local|--global] \"$SHARED_REPO\"" >&2
                echo "  and deleting it from the \`.shared\` file manually by" >&2
                echo "    \$ git hooks shared remove --shared \"$SHARED_REPO\"" >&2
                continue
            fi

            if [ -d "$SHARED_ROOT/.git" ]; then
                echo "* Updating shared hooks from: $SHARED_REPO" >&2

                # shellcheck disable=SC2086
                PULL_OUTPUT=$(execute_git "$SHARED_ROOT" pull 2>&1)

                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Update failed, git pull output:" >&2
                    echo "$PULL_OUTPUT" >&2
                fi
            else
                echo "* Retrieving shared hooks from: $SHARED_REPO_CLONE_URL" >&2

                ADD_ARGS=""
                [ "$SHARED_REPO_IS_LOCAL" != "true" ] && ADD_ARGS="--depth=1"

                [ -d "$SHARED_ROOT" ] &&
                    rm -rf "$SHARED_ROOT"
                mkdir -p "$SHARED_ROOT"

                if [ -n "$SHARED_REPO_CLONE_BRANCH" ]; then
                    # shellcheck disable=SC2086
                    CLONE_OUTPUT=$(git clone \
                        -c core.hooksPath=/dev/null \
                        --template=/dev/null \
                        --single-branch \
                        --branch "$SHARED_REPO_CLONE_BRANCH" \
                        $ADD_ARGS \
                        "$SHARED_REPO_CLONE_URL" \
                        "$SHARED_ROOT" 2>&1)
                else
                    # shellcheck disable=SC2086
                    CLONE_OUTPUT=$(git clone \
                        -c core.hooksPath=/dev/null \
                        --template=/dev/null \
                        --single-branch \
                        $ADD_ARGS \
                        "$SHARED_REPO_CLONE_URL" \
                        "$SHARED_ROOT" 2>&1)
                fi

                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Clone failed, git clone output:" >&2
                    echo "$CLONE_OUTPUT" >&2
                fi
            fi
            IFS="$IFS_NEWLINE"
        done

        unset IFS
    fi
}

#####################################################
# Execute the shared hooks in the
#   $INSTALL_DIR/shared directory.
#
# Returns:
#   1 in case a hook fails, 0 otherwise
#####################################################
execute_shared_hooks() {

    IFS="$IFS_NEWLINE"
    for SHARED_REPO in $SHARED_REPOS_LIST; do
        unset IFS

        set_shared_root "$SHARED_REPO"

        if echo "$EXECUTED_SHARED_HOOKS" | grep -F -q "$SHARED_ROOT"; then
            echo "! Note: Shared hooks entry:" >&2
            echo "  \`$SHARED_REPO\`" >&2
            echo "  is already listed and will be skipped." >&2
            continue
        fi

        if [ "$SHARED_HOOKS_TYPE" = "--shared" ] &&
            [ "$SHARED_REPO_IS_LOCAL" = "true" ]; then
            echo "! Shared hooks in \`.githooks/.shared\` contain a local path" >&2
            echo "  \`$SHARED_REPO\`" >&2
            echo "  which is forbidden." >&2
            echo "" >&2
            echo "  You can only have local paths in shared hooks defined" >&2
            echo "  in the local or global Git configuration." >&2
            echo "" >&2
            echo "  You need to fix this by running" >&2
            echo "    \$ git hooks shared add [--local|--global] \"$SHARED_REPO\"" >&2
            echo "  and deleting it from the \`.shared\` file by" >&2
            echo "    \$ git hooks shared remove --shared \"$SHARED_REPO\"" >&2
            return 1
        fi

        if [ ! -d "$SHARED_ROOT" ]; then

            echo "! Failed to execute shared hooks in \`$SHARED_REPO\`" >&2
            if [ "$SHARED_REPO_IS_CLONED" = "true" ]; then
                echo "  It is not available. To fix, run:" >&2
                echo "    \$ git hooks shared update" >&2
            else
                echo "  It does not exist." >&2
            fi

            if [ "$FAIL_ON_NOT_EXISTING_SHARED_HOOK" = "true" ]; then
                return 1
            else
                echo "  Continuing..." >&2
                continue
            fi
        fi

        if [ "$SHARED_REPO_IS_CLONED" = "true" ]; then
            # Note: GIT_DIR might be set (?bug?) (actually the case for post-checkout hook)
            # which means we really need a `-f` to sepcify the actual config!
            REMOTE_URL=$(git -C "$SHARED_ROOT" config -f "$SHARED_ROOT/.git/config" --get remote.origin.url)
            if ! echo "$SHARED_REPOS_LIST" | grep -F -q "$REMOTE_URL"; then
                echo "! Failed to execute shared hooks in \`$SHARED_REPO\`" >&2
                echo "  The remote URL \`$REMOTE_URL\` is different." >&2
                echo "  To fix it, run:" >&2
                echo "    \$ git hooks shared purge" >&2
                echo "    \$ git hooks shared update" >&2

                if [ "$FAIL_ON_NOT_EXISTING_SHARED_HOOK" = "true" ]; then
                    return 1
                else
                    echo "  Continuing..." >&2
                    continue
                fi
            fi
        fi

        if [ -d "${SHARED_ROOT}/.githooks" ]; then
            execute_all_hooks_in "${SHARED_ROOT}/.githooks" "$@" || return 1
        elif [ -d "$SHARED_ROOT" ]; then
            execute_all_hooks_in "$SHARED_ROOT" "$@" || return 1
        fi

        EXECUTED_SHARED_HOOKS="$SHARED_ROOT
$EXECUTED_SHARED_HOOKS"

        IFS="$IFS_NEWLINE"
    done
    unset IFS
}

#####################################################
# Checks in an update is available,
#   and optionally executes it.
#
# Returns:
#   None
#####################################################
check_for_updates_if_needed() {
    read_last_update_time
    should_run_update_checks || return
    record_update_time
    fetch_latest_updates || return

    if ! is_update_available; then
        # stop here if things are up-to-date
        echo "* Githooks is on the latest version" >&2
        return
    fi

    should_run_update && execute_update && return
    print_update_disable_info
}

#####################################################
# Read the last time we have run an update check.
#
# Sets the ${LAST_UPDATE} variable.
#
# Returns:
#   None
#####################################################
read_last_update_time() {
    LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
    if [ -z "$LAST_UPDATE" ]; then
        LAST_UPDATE=0
    fi
}

#####################################################
# Saves the last update time into the
#   githooks.autoupdate.lastrun global Git config.
#
# Returns:
#   None
#####################################################
record_update_time() {
    git config --global githooks.autoupdate.lastrun "$(date +%s)"
}

#####################################################
# Checks an update check should run already,
#   and updates are not disabled.
#
# Returns:
#   1 if updates should not run, 0 otherwise
#####################################################
should_run_update_checks() {
    [ "$HOOK_NAME" != "post-commit" ] && return 1

    UPDATES_ENABLED=$(git config --get githooks.autoupdate.enabled)
    [ "$UPDATES_ENABLED" != "true" ] &&
        [ "$UPDATES_ENABLED" != "Y" ] && return 1

    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - LAST_UPDATE))
    ONE_DAY=86400

    if [ $ELAPSED_TIME -lt $ONE_DAY ]; then
        return 1 # it is not time to update yet
    fi
}

#####################################################
# Returns the script path e.g. `run` for the app
#   `$1`
#
# Returns:
#   0 and "$INSTALL_DIR/tools/$1/run"
#   1 and "" otherwise
#####################################################
get_tool_script() {
    if [ -f "$INSTALL_DIR/tools/$1/run" ]; then
        echo "$INSTALL_DIR/tools/$1/run" && return 0
    fi
    return 1
}

#####################################################
# Execute the script at "$1".
#   If it is not executable then
#   call it as a shell script.
#
# Returns:
#   The error code of the script
#####################################################
call_script() {
    SCRIPT="$1"
    shift

    if [ -x "$SCRIPT" ]; then
        "$SCRIPT" "$@"
    else
        sh "$SCRIPT" "$@"
    fi

    return $?
}

#####################################################
# Show a prompt with the text `$2` with
#   hint text `$3` with
#   options `$4` in form of e.g. `Y/a/n/d` and
#   optional long options [optional]:
#     e.g. `$5-$8` : "Yes" "All" "None" "Disable"
#   First capital short option character is treated
#   as default.
#   The result is set in the variable named in `$1`.
#
#####################################################
show_prompt() {
    DIALOG_TOOL="$(get_tool_script "dialog")"
    VARIABLE="$1"
    shift
    TEXT="$1"
    shift
    HINT_TEXT="$1"
    shift
    SHORT_OPTIONS="$1"
    shift

    if [ "$DIALOG_TOOL" != "" ]; then
        ANSWER=$(call_script "$DIALOG_TOOL" "githook::" "$TEXT" "$SHORT_OPTIONS" "$@")
        # shellcheck disable=SC2181
        if [ $? -eq 0 ]; then
            if ! echo "$SHORT_OPTIONS" | grep -F -q "$ANSWER"; then
                echo "! Dialog tool did return wrong answer $ANSWER -> Abort." >&2
                exit 1
            fi

            # Safeguard `eval`
            if ! echo "$VARIABLE" | grep -qE "^[A-Z_]+\$"; then
                echo "! Invalid variable name: $VARIABLE" >&2
                exit 1
            fi

            eval "$VARIABLE"="$ANSWER"
            return
        fi

        # else: Running fallback...
    fi

    # Try to read from `dev/tty` if available.
    # Our stdin is never a tty (either a pipe or /dev/null when called
    # from git), so read from /dev/tty, our controlling terminal,
    # if it can be opened.
    printf "%s %s [%s]:" "$TEXT" "$HINT_TEXT" "$SHORT_OPTIONS" >&2

    # shellcheck disable=SC2217
    if true </dev/tty 2>/dev/null; then
        # shellcheck disable=SC2229
        read -r "$VARIABLE" </dev/tty
    fi

    # If the above gives any error
    # e.g. /dev/tty could not be opened or `read` returned an error,
    # ${$VARIABLE} is not changed
    # and we leave the decision to the caller.
}

#####################################################
# Fetches updates in the release clone.
#   If the release clone is newly created the variable
#   `$GITHOOKS_CLONE_CREATED` is set to
#   `true`
#   If an update is available
#   `GITHOOKS_CLONE_UPDATE_AVAILABLE` is set to `true`
#
# Returns:
#   1 if failed, 0 otherwise
#####################################################
fetch_latest_updates() {

    echo "^ Checking for updates ..." >&2

    GITHOOKS_CLONE_CREATED="false"
    GITHOOKS_CLONE_UPDATE_AVAILABLE="false"

    GITHOOKS_CLONE_URL=$(git config --global githooks.cloneUrl)
    GITHOOKS_CLONE_BRANCH=$(git config --global githooks.cloneBranch)

    # We do a fresh clone if there is not repository
    if is_git_repo "$GITHOOKS_CLONE_DIR"; then

        URL=$(execute_git "$GITHOOKS_CLONE_DIR" config remote.origin.url 2>/dev/null)
        BRANCH=$(execute_git "$GITHOOKS_CLONE_DIR" symbolic-ref -q --short HEAD 2>/dev/null)

        if [ "$URL" != "$GITHOOKS_CLONE_URL" ] ||
            [ "$BRANCH" != "$GITHOOKS_CLONE_BRANCH" ]; then
            echo "! Cannot fetch updates because \`origin\` of update clone" >&2
            echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
            echo "  points to url:" >&2
            echo "  \`$URL\`" >&2
            echo "  on branch \`$BRANCH\`" >&2
            echo "  which is not configured." >&2
            echo "  See \`git hooks config [set|print] clone-url\` and" >&2
            echo "      \`git hooks config [set|print] clone-branch\`" >&2
            echo "  Either fix this or delete the clone" >&2
            echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
            echo "  to trigger a new checkout." >&2
            return 1
        fi

        FETCH_OUTPUT=$(
            execute_git "$GITHOOKS_CLONE_DIR" fetch origin "$GITHOOKS_CLONE_BRANCH" 2>&1
        )

        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo "! Fetching updates in  \`$GITHOOKS_CLONE_DIR\` failed with:" >&2
            echo "$FETCH_OUTPUT" >&2
            return 1
        fi

        CURRENT_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse "$GITHOOKS_CLONE_BRANCH")
        UPDATE_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse "origin/$GITHOOKS_CLONE_BRANCH")

        if [ "$CURRENT_COMMIT" != "$UPDATE_COMMIT" ]; then
            # We have an update available
            # install.sh deals with updating ...
            GITHOOKS_CLONE_UPDATE_AVAILABLE="true"
            UPDATED_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse --short=6 "origin/$GITHOOKS_CLONE_BRANCH")
            UPDATED_COMMIT_DATE=$(execute_git "$GITHOOKS_CLONE_DIR" log -1 "--date=format:%y%m.%d%H%M" --format="%cd" "origin/$GITHOOKS_CLONE_BRANCH")
            GITHOOKS_CLONE_UPDATE_VERSION="${UPDATED_COMMIT_DATE}-${UPDATED_COMMIT}"
        fi

    else
        clone_release_repository || return 1

        # shellcheck disable=SC2034
        GITHOOKS_CLONE_CREATED="true"
        GITHOOKS_CLONE_UPDATE_AVAILABLE="true"
        UPDATED_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse --short=6 "$GITHOOKS_CLONE_BRANCH")
        UPDATED_COMMIT_DATE=$(execute_git "$GITHOOKS_CLONE_DIR" log -1 "--date=format:%y%m.%d%H%M" --format="%cd" "$GITHOOKS_CLONE_BRANCH")
        GITHOOKS_CLONE_UPDATE_VERSION="${UPDATED_COMMIT_DATE}-${UPDATED_COMMIT}"
    fi

    return 0
}

############################################################
# Clone the URL `$GITHOOKS_CLONE_URL` into the install
#   folder `GITHOOKS_CLONE_DIR` for further updates.
#   Sets `$GITHOOKS_CLONE_CREATED`.
#
# Returns: 0 if successful, 1 otherwise
############################################################
clone_release_repository() {
    GITHOOKS_CLONE_URL=$(git config --global githooks.cloneUrl)
    GITHOOKS_CLONE_BRANCH=$(git config --global githooks.cloneBranch)

    if [ -z "$GITHOOKS_CLONE_URL" ]; then
        GITHOOKS_CLONE_URL="https://github.com/rycus86/githooks.git"
    fi

    if [ -z "$GITHOOKS_CLONE_BRANCH" ]; then
        GITHOOKS_CLONE_BRANCH="master"
    fi

    if [ -d "$GITHOOKS_CLONE_DIR" ]; then
        if ! rm -rf "$GITHOOKS_CLONE_DIR" >/dev/null 2>&1; then
            echo "! Failed to remove an existing githooks release repository" >&2
            return 1
        fi
    fi

    echo "Cloning \`$GITHOOKS_CLONE_URL\` to \`$GITHOOKS_CLONE_DIR\` ..." >&2

    CLONE_OUTPUT=$(git clone \
        -c core.hooksPath=/dev/null \
        --template=/dev/null \
        --depth=1 \
        --single-branch \
        --branch "$GITHOOKS_CLONE_BRANCH" \
        "$GITHOOKS_CLONE_URL" \
        "$GITHOOKS_CLONE_DIR" 2>&1)

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Cloning \`$GITHOOKS_CLONE_URL\` to \`$GITHOOKS_CLONE_DIR\` failed with output: " >&2
        echo "$CLONE_OUTPUT" >&2
        return 1
    fi

    git config --global githooks.cloneUrl "$GITHOOKS_CLONE_URL"
    git config --global githooks.cloneBranch "$GITHOOKS_CLONE_BRANCH"

    return 0
}

############################################################
# Checks whether the given directory
#   is a Git repository (bare included) or not.
#
# Returns:
#   1 if failed, 0 otherwise
############################################################
is_git_repo() {
    git -C "$1" rev-parse >/dev/null 2>&1 || return 1
}

############################################################
# Checks whether the given directory
#   is a Git bare repository.
#
# Returns:
#   1 if failed, 0 otherwise
############################################################
is_bare_repo() {
    [ "$(git -C "$1" rev-parse --is-bare-repository 2>/dev/null)" = "true" ] || return 1
}

#####################################################
# Safely execute a git command in the
#   clone dir `$1`.
#
# Returns: Error code from `git`
#####################################################
execute_git() {
    REPO="$1"
    shift

    git -C "$REPO" \
        --work-tree="$REPO" \
        --git-dir="$REPO/.git" \
        -c core.hooksPath=/dev/null \
        "$@"
}

#####################################################
# Checks if there is an update in the release clone
#   waiting for a fast-forward merge.
#
# Returns:
#   0 if an update needs to be applied, 1 otherwise
#####################################################
is_update_available() {
    [ "$GITHOOKS_CLONE_UPDATE_AVAILABLE" = "true" ] || return 1
}

#####################################################
# Checks if an update was applied
#  in the release clone. A clone is also an update.
#
# Returns:
#   0 if an update was applied, 1 otherwise
#####################################################
is_clone_created() {
    [ "$GITHOOKS_CLONE_CREATED" = "true" ] || return 1
}

#####################################################
# Prompts the user whether the new update
#   should be installed or not.
#
# Returns:
#   0 if it should be, 1 otherwise
#####################################################
should_run_update() {

    if is_update_available; then

        MESSAGE="$(printf "%s\n%s" \
            "* There is a new Githooks update available: Forward-merge to version \"${GITHOOKS_CLONE_UPDATE_VERSION}\"" \
            "Would you like to install it now?")"
        show_prompt EXECUTE_UPDATE "$MESSAGE" "(Yes, no)" "Y/n" "Yes" "no"

        if [ -z "$EXECUTE_UPDATE" ] || [ "$EXECUTE_UPDATE" = "y" ] || [ "$EXECUTE_UPDATE" = "Y" ]; then
            return 0
        else
            return 1
        fi
    else
        echo "* Githooks is on the latest version" >&2
        return 1
    fi
}

#####################################################
# Performs the installation of the latest update.
#
# Returns:
#   0 if the update was successful, 1 otherwise
#####################################################
execute_update() {

    INSTALL_SCRIPT="$GITHOOKS_CLONE_DIR/install.sh"
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        echo "! No install script in folder \`$GITHOOKS_CLONE_DIR/\`" >&2
        return 1
    fi

    sh -s -- --internal-autoupdate --internal-install <"$INSTALL_SCRIPT" >&2 || return 1
    return 0
}

#####################################################
# Prints some information on how to disable
#   automatic update checks.
#
# Returns:
#   None
#####################################################
print_update_disable_info() {
    echo "  If you would like to disable auto-updates, run:" >&2
    echo "    \$ git hooks update disable" >&2
}

# Start processing the hooks
process_git_hook "$@" || exit 1
