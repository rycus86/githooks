#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.
#
# Version: 1911.160112-e4948d

#####################################################
# Execute the current hook,
#   that in turn executes the hooks in the repo.
#
# Returns:
#   0 when successfully finished, 1 otherwise
#####################################################
process_git_hook() {
    if are_githooks_disabled; then
        set_main_variables
        execute_lfs_hook_if_appropriate "$@" || return 1
        return
    fi

    set_main_variables
    export_staged_files
    check_for_updates_if_needed
    execute_old_hook_if_available "$@" || return 1
    execute_lfs_hook_if_appropriate "$@" || return 1
    execute_global_shared_hooks "$@" || return 1
    execute_local_shared_hooks "$@" || return 1
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
    if [ "$GITHOOKS_CONFIG_DISABLE" = "y" ] || [ "$GITHOOKS_CONFIG_DISABLE" = "Y" ]; then
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
        echo "  Install directory at ${INSTALL_DIR} is missing." >&2
        INSTALL_DIR=~/".githooks"
        echo "  Falling back to default directory at ${INSTALL_DIR}" >&2
        echo "  Please run the Githooks install script again to fix it." >&2
    fi
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
# Returns: None
#####################################################
set_main_variables() {
    HOOK_NAME=$(basename "$0")
    HOOK_FOLDER=$(dirname "$0")
    ACCEPT_CHANGES=

    CURRENT_GIT_DIR=$(git rev-parse --git-common-dir)
    if [ "${CURRENT_GIT_DIR}" = "--git-common-dir" ]; then
        CURRENT_GIT_DIR=".git" # reset to a sensible default
    fi

    load_install_dir

    # Global IFS for loops
    IFS_COMMA_NEWLINE=",
"
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

    # shellcheck disable=2181
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
# Check if we have shared hooks set up globally,
#   and execute all of them if we do.
#
# Returns:
#   1 if the hooks fail, 0 otherwise
#####################################################
execute_global_shared_hooks() {
    SHARED_HOOKS=$(git config --global --get githooks.shared)

    if [ -n "$SHARED_HOOKS" ]; then
        process_shared_hooks "$SHARED_HOOKS" "$@" || return 1
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
execute_local_shared_hooks() {
    if [ -f "$(pwd)/.githooks/.shared" ]; then
        SHARED_HOOKS=$(grep -E "^[^#].+$" <"$(pwd)/.githooks/.shared")
        process_shared_hooks "$SHARED_HOOKS" "$@" || return 1
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
    if [ -f ".githooks/trust-all" ]; then
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
    if ! MD5_HASH=$(md5 -r "$HOOK_PATH" 2>/dev/null); then
        MD5_HASH=$(md5sum "$HOOK_PATH" 2>/dev/null)
    fi
    MD5_HASH=$(echo "$MD5_HASH" | awk "{ print \$1 }")
    CURRENT_HASHES=$(grep "$HOOK_PATH" "$CURRENT_GIT_DIR/.githooks.checksum" 2>/dev/null)

    # check against the previous hash
    if echo "$CURRENT_HASHES" | grep -q "disabled> $HOOK_PATH" >/dev/null 2>&1; then
        echo "* Skipping disabled $HOOK_PATH"
        echo "  Use \`git hooks enable $HOOK_NAME $(basename "$HOOK_PATH")\` to enable it again"
        echo "  Alternatively, edit or delete the $(pwd)/$CURRENT_GIT_DIR/.githooks.checksum file to enable it again"
        return 1

    elif ! echo "$CURRENT_HASHES" | grep -q "$MD5_HASH $HOOK_PATH" >/dev/null 2>&1; then
        if [ -z "$CURRENT_HASHES" ]; then
            MESSAGE="New hook file found"
        else
            MESSAGE="Hook file changed"
        fi

        if [ "$ACCEPT_CHANGES" = "a" ] || [ "$ACCEPT_CHANGES" = "A" ]; then
            echo "? $MESSAGE: $HOOK_PATH"
            echo "  Already accepted"
        else
            MESSAGE="$(printf "%s\n%s" "$MESSAGE: $HOOK_PATH" "  Do you accept the changes?")"
            show_prompt ACCEPT_CHANGES "? $MESSAGE" "(Yes, all, no, disable)" "Y/a/n/d" "Yes" "All" "No" "Disable"

            if [ "$ACCEPT_CHANGES" = "n" ] || [ "$ACCEPT_CHANGES" = "N" ]; then
                echo "* Not running $HOOK_FILE"
                return 1
            fi

            if [ "$ACCEPT_CHANGES" = "d" ] || [ "$ACCEPT_CHANGES" = "D" ]; then
                echo "* Disabled $HOOK_PATH"
                echo "  Use \`git hooks enable $HOOK_NAME $(basename "$HOOK_PATH")\` to enable it again"
                echo "  Alternatively, edit or delete the $(pwd)/$CURRENT_GIT_DIR/.githooks.checksum file to enable it again"

                echo "disabled> $HOOK_PATH" >>$CURRENT_GIT_DIR/.githooks.checksum
                return 1
            fi
        fi

        # save the new accepted checksum
        echo "$MD5_HASH $HOOK_PATH" >>$CURRENT_GIT_DIR/.githooks.checksum
    fi
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
    SHARED_REPOS_LIST="$1"
    shift

    update_shared_hooks_if_appropriate "$@"
    execute_shared_hooks "$@" || return 1
}

#####################################################
# Sets the SHARED_ROOT and NORMALIZED_NAME
#   for the shared hook repo url `$1`.
#
# Returns:
#   none
#####################################################
set_shared_root() {
    NORMALIZED_NAME=$(echo "$1" |
        sed -E "s#.*[:/](.+/.+)\\.git#\\1#" |
        sed -E "s/[^a-zA-Z0-9]/_/g")
    SHARED_ROOT="$INSTALL_DIR/shared/$NORMALIZED_NAME"
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
    [ "$HOOK_NAME" = ".githooks.shared.trigger" ] && RUN_UPDATE="true"
    [ "$HOOK_NAME" = "post-checkout" ] && [ "$1" = "$GIT_NULL_REF" ] && RUN_UPDATE="true"

    if [ "$RUN_UPDATE" = "true" ]; then
        # split on comma and newline
        IFS="$IFS_COMMA_NEWLINE"

        for SHARED_REPO in $SHARED_REPOS_LIST; do
            unset IFS
            mkdir -p "$INSTALL_DIR/shared"

            set_shared_root "$SHARED_REPO"

            if [ -d "$SHARED_ROOT/.git" ]; then
                echo "* Updating shared hooks from: $SHARED_REPO"
                PULL_OUTPUT=$(cd "$SHARED_ROOT" && git pull 2>&1)
                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Update failed, git pull output:" >&2
                    echo "$PULL_OUTPUT" >&2
                fi
            else
                echo "* Retrieving shared hooks from: $SHARED_REPO"
                [ -d "$SHARED_ROOT" ] && rm -rf "$SHARED_ROOT"
                CLONE_OUTPUT=$(git clone "$SHARED_REPO" "$SHARED_ROOT" 2>&1)
                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Clone failed, git clone output:" >&2
                    echo "$CLONE_OUTPUT" >&2
                fi
            fi
            IFS="$IFS_COMMA_NEWLINE"
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
    # split on comma and newline
    IFS="$IFS_COMMA_NEWLINE"

    # Fail if the shared root is not available (if enabled)
    FAIL_ON_NOT_EXISTING=$(git config --get githooks.failOnNonExistingSharedHooks)

    for SHARED_REPO in $SHARED_REPOS_LIST; do
        unset IFS

        set_shared_root "$SHARED_REPO"

        if [ ! -f "$SHARED_ROOT/.git/config" ]; then
            echo "! Failed to execute shared hooks in $SHARED_REPO" >&2
            echo "  It is not available. To fix, run:" >&2
            echo "    \$ git hooks shared update" >&2

            if [ "$FAIL_ON_NOT_EXISTING" = "true" ]; then
                return 1
            else
                echo "  Continuing..." >&2
                continue
            fi
        fi

        # Note: GIT_DIR might be set (?bug?) (actually the case for post-checkout hook)
        # which means we really need a `-f` to sepcify the actual config!
        REMOTE_URL=$(cd "$SHARED_ROOT" && git config -f "$SHARED_ROOT/.git/config" --get remote.origin.url)
        ACTIVE_REPO=$(echo "$SHARED_REPOS_LIST" | grep -o "$REMOTE_URL")
        if [ "$ACTIVE_REPO" != "$REMOTE_URL" ]; then
            echo "! Failed to execute shared hooks in $SHARED_REPO" >&2
            echo "  The URL \`$REMOTE_URL\` is different." >&2
            echo "  To fix it, run:" >&2
            echo "    \$ git hooks shared purge" >&2
            echo "    \$ git hooks shared update" >&2

            if [ "$FAIL_ON_NOT_EXISTING" = "true" ]; then
                return 1
            else
                echo "  Continuing..." >&2
                continue
            fi
        fi

        if [ -d "${SHARED_ROOT}/.githooks" ]; then
            execute_all_hooks_in "${SHARED_ROOT}/.githooks" "$@" || return 1
        elif [ -d "$SHARED_ROOT" ]; then
            execute_all_hooks_in "$SHARED_ROOT" "$@" || return 1
        fi

        IFS="$IFS_COMMA_NEWLINE"
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
    fetch_latest_update_script || return
    read_updated_version_number
    is_update_available || return
    read_single_repo_information
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
            if ! echo "$SHORT_OPTIONS" | grep -q "$ANSWER"; then
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

    # Read from stdin
    printf "%s %s [%s]:" "$TEXT" "$HINT_TEXT" "$SHORT_OPTIONS"
    # shellcheck disable=SC2229
    read -r "$VARIABLE" </dev/tty
}

#####################################################
# Downloads a file "$1" with `wget` or `curl`
#
# Returns:
#   0 if download succeeded, 1 otherwise
#####################################################
download_file() {
    DOWNLOAD_FILE="$1"
    OUTPUT_FILE="$2"
    DOWNLOAD_TOOL="$(get_tool_script "download")"

    if [ "$DOWNLOAD_TOOL" != "" ]; then
        # Use the external download tool for downloading the file
        call_script "$DOWNLOAD_TOOL" "$DOWNLOAD_FILE" "$OUTPUT_FILE"
    else
        # The main update url.
        MAIN_DOWNLOAD_URL="https://raw.githubusercontent.com/rycus86/githooks/master"

        # Default implementation
        DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/$DOWNLOAD_FILE"

        if curl --version >/dev/null 2>&1; then
            curl -fsSL "$DOWNLOAD_URL" -o "$OUTPUT_FILE" >/dev/null 2>&1
        elif wget --version >/dev/null 2>&1; then
            wget -O "$OUTPUT_FILE" "$DOWNLOAD_URL" >/dev/null 2>&1
        else
            echo "! Cannot download file \`$DOWNLOAD_URL\` - needs either curl or wget" >&2
            return 1
        fi
    fi

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Cannot download file \`$DOWNLOAD_FILE\` - command failed" >&2
        return 1
    fi
    return 0
}

#####################################################
# Loads the contents of the latest install
#   script into a variable.
#
# Sets the ${INSTALL_SCRIPT} variable
#
# Returns:
#   1 if failed the load the script, 0 otherwise
#####################################################
fetch_latest_update_script() {
    echo "^ Checking for updates ..."

    INSTALL_SCRIPT="$(mktemp)"
    if ! download_file "install.sh" "$INSTALL_SCRIPT"; then
        echo "! Failed to check for updates" >&2
        return 1
    fi
}

#####################################################
# Reads the version number of the latest
#   install script into a variable.
#
# Sets the ${LATEST_VERSION} variable
#
# Returns:
#   None
#####################################################
read_updated_version_number() {
    LATEST_VERSION=$(grep -E "^# Version: .*" <"$INSTALL_SCRIPT" | head -1 | sed -E "s/^# Version: //")
}

#####################################################
# Checks if the latest install script is
#   newer than what we have installed already.
#
# Returns:
#   0 if the script is newer, 1 otherwise
#####################################################
is_update_available() {
    CURRENT_VERSION=$(grep -E "^# Version: .*" "$0" | head -1 | sed -E "s/^# Version: //")
    UPDATE_AVAILABLE=$(echo "$CURRENT_VERSION $LATEST_VERSION" | awk "{ print (\$1 >= \$2) }")
    [ "$UPDATE_AVAILABLE" = "0" ] || return 1
}

#####################################################
# Reads whether the hooks in the current
#   local repository were installed in
#   single repository install mode.
#
# Sets the ${IS_SINGLE_REPO} variable
#
# Returns:
#   None
#####################################################
read_single_repo_information() {
    IS_SINGLE_REPO=$(git config --get --local githooks.single.install)
}

#####################################################
# Checks if the hooks in the current
#   local repository were installed in
#   single repository install mode.
#
# Returns:
#   0 if they were, 1 otherwise
#####################################################
is_single_repo() {
    [ "$IS_SINGLE_REPO" = "yes" ] || return 1
}

#####################################################
# Prompts the user whether the new update
#   should be installed or not.
#
# Returns:
#   0 if it should be, 1 otherwise
#####################################################
should_run_update() {
    MESSAGE="$(printf "%s\n%s" "* There is a new Githooks update available: Version $LATEST_VERSION" "Would you like to install it now?")"
    show_prompt EXECUTE_UPDATE "$MESSAGE" "(Yes, no)" "Y/n" "Yes" "no"

    if [ -z "$EXECUTE_UPDATE" ] || [ "$EXECUTE_UPDATE" = "y" ] || [ "$EXECUTE_UPDATE" = "Y" ]; then
        return 0
    else
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
    if is_single_repo; then
        if sh -s -- --single <"$INSTALL_SCRIPT"; then
            return 0
        fi
    else
        if sh <"$INSTALL_SCRIPT"; then
            return 0
        fi
    fi

    return 1
}

#####################################################
# Prints some information on how to disable
#   automatic update checks.
#
# Returns:
#   None
#####################################################
print_update_disable_info() {
    echo "  If you would like to disable auto-updates, run:"
    echo "    \$ git hooks update disable"
}

# Start processing the hooks
process_git_hook "$@" || exit 1
