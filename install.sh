#!/bin/sh
#
# Installs the base Git hook templates from https://github.com/rycus86/githooks
#   and performs some optional setup for existing repositories.
#   See the documentation in the project README for more information.
#
# Version: 2004.162028-00b20e

# The list of hooks we can manage with this script
MANAGED_HOOK_NAMES="
    applypatch-msg pre-applypatch post-applypatch
    pre-commit prepare-commit-msg commit-msg post-commit
    pre-rebase post-checkout post-merge pre-push
    pre-receive update post-receive post-update
    push-to-checkout pre-auto-gc post-rewrite sendemail-validate
"

MANAGED_SERVER_HOOK_NAMES="
    pre-push pre-receive update post-receive post-update
    push-to-checkout pre-auto-gc
"

# A copy of the base-template.sh file's contents
# shellcheck disable=SC2016
BASE_TEMPLATE_CONTENT='#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.
#
# Version: 2004.162028-00b20e

#####################################################
# Execute the current hook,
#   that in turn executes the hooks in the repo.
#
# Returns:
#   0 when successfully finished, 1 otherwise
#####################################################
process_git_hook() {
    set_main_variables
    register_for_autoupdate_if_needed

    if are_githooks_disabled; then
        execute_lfs_hook_if_appropriate "$@" || return 1
        execute_old_hook_if_available "$@" || return 1
        return
    fi

    export_staged_files
    check_for_updates_if_needed
    execute_lfs_hook_if_appropriate "$@" || return 1
    execute_old_hook_if_available "$@" || return 1
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

    CURRENT_GIT_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
    if [ ! -d "${CURRENT_GIT_DIR}" ]; then
        echo "! Hook not run inside a git repository" >&2 && exit 1
    fi

    load_install_dir

    # Global IFS for loops
    IFS_COMMA_NEWLINE=",
"
}

############################################################
# We register this repository for future potential
# autoupdates if all of the following is true
#   - core.hooksPath is not defined, meaning this hook
#     needs to be in `.git/hooks`.
#   - its not yet registered.
#   - its a non-single install.
#
# Returns: None
############################################################
register_for_autoupdate_if_needed() {
    if ! git config --local githooks.autoupdate.registered >/dev/null 2>&1 &&
        [ "$(git config --local githooks.single.install)" != "yes" ] &&
        [ ! -d "$(git config --global core.hooksPath)" ]; then
        register_repo_for_autoupdate "$CURRENT_GIT_DIR"
    fi
}

############################################################
# Adds the repository to the list `autoupdate.registered`
#  for future potential autoupdate.
#
# Returns: None
############################################################
register_repo_for_autoupdate() {
    CURRENT_REPO="$(cd "$1" && pwd)"
    LIST="$INSTALL_DIR/autoupdate/registered"

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
    git config --local githooks.autoupdate.registered "yes"
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

                echo "disabled> $HOOK_PATH" >>"$CURRENT_GIT_DIR/.githooks.checksum"
                return 1
            fi
        fi

        # save the new accepted checksum
        echo "$MD5_HASH $HOOK_PATH" >>"$CURRENT_GIT_DIR/.githooks.checksum"
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
                PULL_OUTPUT=$(git -C "$SHARED_ROOT" --work-tree="$SHARED_ROOT" --git-dir="$SHARED_ROOT/.git" -c core.hooksPath=/dev/null pull 2>&1)
                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Update failed, git pull output:" >&2
                    echo "$PULL_OUTPUT" >&2
                fi
            else
                echo "* Retrieving shared hooks from: $SHARED_REPO"
                [ -d "$SHARED_ROOT" ] && rm -rf "$SHARED_ROOT"
                CLONE_OUTPUT=$(git -c core.hooksPath=/dev/null clone "$SHARED_REPO" "$SHARED_ROOT" 2>&1)
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
        REMOTE_URL=$(git -C "$SHARED_ROOT" config -f "$SHARED_ROOT/.git/config" --get remote.origin.url)
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

    # Try to read from `dev/tty` if available.
    # Our stdin is never a tty (either a pipe or /dev/null when called
    # from git), so read from /dev/tty, our controlling terminal.
    # However, only do this when stdout *is* a tty, otherwise it is
    # likely we have no controlling terminal and reading from /dev/tty
    # would fail with an error.
    if [ -t 0 ] && [ -t 1 ]; then
        printf "%s %s [%s]:" "$TEXT" "$HINT_TEXT" "$SHORT_OPTIONS"
        # shellcheck disable=SC2229
        read -r "$VARIABLE" </dev/tty
    fi

    # By default: If we end up here we do not modify the variable
    # and gracefully do nothing, leaving the decision to the caller.
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
        if DO_UPDATE_ONLY="yes" sh -s -- --single <"$INSTALL_SCRIPT"; then
            return 0
        fi
    else
        if DO_UPDATE_ONLY="yes" sh <"$INSTALL_SCRIPT"; then
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
'

# A copy of the cli.sh file's contents
# shellcheck disable=SC2016
CLI_TOOL_CONTENT='#!/bin/sh
#
# Command line helper for https://github.com/rycus86/githooks
#
# This tool provides a convenience utility to manage
#   Githooks configuration, hook files and other
#   related functionality.
# This script should be an alias for `git hooks`, done by
#   git config --global alias.hooks "!${SCRIPT_DIR}/githooks"
#
# See the documentation in the project README for more information,
#   or run the `git hooks help` command for available options.
#
# Version: 2004.162028-00b20e

#####################################################
# Prints the command line help for usage and
#   available commands.
#####################################################
print_help() {
    print_help_header

    echo "
Available commands:

    disable     Disables a hook in the current repository
    enable      Enables a previously disabled hook in the current repository
    accept      Accepts the pending changes of a new or modified hook
    trust       Manages settings related to trusted repositories
    list        Lists the active hooks in the current repository
    shared      Manages the shared hook repositories
    install     Installs the latest Githooks hooks
    uninstall   Uninstalls the Githooks hooks
    update      Performs an update check
    readme      Manages the Githooks README in the current repository
    ignore      Manages Githooks ignore files in the current repository
    config      Manages various Githooks configuration
    tools       Manages script folders for tools
    version     Prints the version number of this script
    help        Prints this help message

You can also execute \`git hooks <cmd> help\` for more information on the individual commands.
"
}

#####################################################
# Prints a general header to be included
#   as the first few lines of every help message.
#####################################################
print_help_header() {
    echo
    echo "Githooks - https://github.com/rycus86/githooks"
    echo "----------------------------------------------"
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
# Sets the ${CURRENT_GIT_DIR} variable
#
# Returns: None
#####################################################
set_main_variables() {
    CURRENT_GIT_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
    if [ "${CURRENT_GIT_DIR}" = "--git-common-dir" ]; then
        CURRENT_GIT_DIR=".git"
    fi

    load_install_dir

    # Global IFS for loops
    IFS_COMMA_NEWLINE=",
"
}

#####################################################
# Checks if the current directory is
#   a Git repository or not.

# Returns:
#   0 if it is likely a Git repository,
#   1 otherwise
#####################################################
is_running_in_git_repo_root() {
    git rev-parse >/dev/null 2>&1 || return 1
    [ -d "${CURRENT_GIT_DIR}" ] || return 1
}

#####################################################
# Echo if the current repository is non-bare.
#
# Returns: 0
#####################################################
echo_if_non_bare_repo() {
    if [ "$(git rev-parse --is-bare-repository 2>/dev/null)" = "false" ]; then
        echo "$@"
    fi
    return 0
}

#####################################################
# Finds a hook file path based on trigger name,
#   file name, relative or absolute path, or
#   some combination of these.
#
# Sets the ${HOOK_PATH} environment variable.
#
# Returns:
#   0 on success, 1 when no hooks found
#####################################################
find_hook_path_to_enable_or_disable() {
    if [ "$1" = "--shared" ]; then
        shift

        if [ -z "$1" ]; then
            echo "For shared repositories, either the trigger type, the hook name or both needs to be given"
            return 1
        fi

        if [ ! -d "$INSTALL_DIR/shared" ]; then
            echo "No shared repositories found"
            return 1
        fi

        for SHARED_ROOT in "$INSTALL_DIR/shared/"*; do
            if [ ! -d "$SHARED_ROOT" ]; then
                continue
            fi

            REMOTE_URL=$(git -C "$SHARED_ROOT" config --get remote.origin.url)

            SHARED_LOCAL_REPOS_LIST=$(grep -E "^[^#].+$" <"$(pwd)/.githooks/.shared")
            ACTIVE_LOCAL_REPO=$(echo "$SHARED_LOCAL_REPOS_LIST" | grep -o "$REMOTE_URL")

            ACTIVE_GLOBAL_REPO=$(git config --global --get githooks.shared | grep -o "$REMOTE_URL")

            if [ "$ACTIVE_LOCAL_REPO" != "$REMOTE_URL" ] && [ "$ACTIVE_GLOBAL_REPO" != "$REMOTE_URL" ]; then
                continue
            fi

            if [ -n "$1" ] && [ -n "$2" ]; then
                if [ -f "$SHARED_ROOT/.githooks/$1/$2" ]; then
                    HOOK_PATH="$SHARED_ROOT/.githooks/$1/$2"
                    return
                elif [ -f "$SHARED_ROOT/$1/$2" ]; then
                    HOOK_PATH="$SHARED_ROOT/$1/$2"
                    return
                fi
            elif [ -d "$SHARED_ROOT/.githooks" ]; then
                HOOK_PATH=$(find "$SHARED_ROOT/.githooks" -name "$1" | head -1)
                [ -n "$HOOK_PATH" ] && return 0 || return 1
            else
                HOOK_PATH=$(find "$SHARED_ROOT" -name "$1" | head -1)
                [ -n "$HOOK_PATH" ] && return 0 || return 1
            fi
        done

        echo "Sorry, cannot find any shared hooks that would match that"
        return 1
    fi

    if [ -z "$1" ]; then
        HOOK_PATH=$(cd .githooks && pwd)

    elif [ -n "$1" ] && [ -n "$2" ]; then
        HOOK_TARGET="$(pwd)/.githooks/$1/$2"
        if [ -e "$HOOK_TARGET" ]; then
            HOOK_PATH="$HOOK_TARGET"
        fi

    elif [ -n "$1" ]; then
        if [ -e "$1" ]; then
            HOOK_DIR=$(dirname "$1")
            HOOK_NAME=$(basename "$1")

            if [ "$HOOK_NAME" = "." ]; then
                HOOK_PATH=$(cd "$HOOK_DIR" && pwd)
            else
                HOOK_PATH=$(cd "$HOOK_DIR" && pwd)/"$HOOK_NAME"
            fi

        elif [ -f ".githooks/$1" ]; then
            HOOK_PATH=$(cd .githooks && pwd)/"$1"

        else
            for HOOK_DIR in .githooks/*; do
                HOOK_ITEM=$(basename "$HOOK_DIR")
                if [ "$HOOK_ITEM" = "$1" ]; then
                    HOOK_PATH=$(cd "$HOOK_DIR" && pwd)
                fi

                if [ ! -d "$HOOK_DIR" ]; then
                    continue
                fi

                HOOK_DIR=$(cd "$HOOK_DIR" && pwd)

                for HOOK_FILE in "$HOOK_DIR"/*; do
                    HOOK_ITEM=$(basename "$HOOK_FILE")
                    if [ "$HOOK_ITEM" = "$1" ]; then
                        HOOK_PATH="$HOOK_FILE"
                    fi
                done
            done
        fi
    fi

    if [ -z "$HOOK_PATH" ]; then
        echo "Sorry, cannot find any hooks that would match that"
        return 1
    elif echo "$HOOK_PATH" | grep -qv "/.githooks"; then
        if [ -d "$HOOK_PATH/.githooks" ]; then
            HOOK_PATH="$HOOK_PATH/.githooks"
        else
            echo "Sorry, cannot find any hooks that would match that"
            return 1
        fi
    fi
}

#####################################################
# Creates the Githooks checksum file
#   for the repository if it does not exist yet.
#####################################################
ensure_checksum_file_exists() {
    touch "${CURRENT_GIT_DIR}/.githooks.checksum"
}

#####################################################
# Disables one or more hook files
#   in the current repository.
#
# Returns:
#   1 if the current directory is not a Git repo,
#   0 otherwise
#####################################################
disable_hook() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks disable [--shared] [trigger] [hook-script]
git hooks disable [--shared] [hook-script]
git hooks disable [--shared] [trigger]
git hooks disable [-a|--all]
git hooks disable [-r|--reset]

    Disables a hook in the current repository.
    The \`trigger\` parameter should be the name of the Git event if given.
    The \`hook-script\` can be the name of the file to disable, or its
    relative path, or an absolute path, we will try to find it.
    If the \`--shared\` parameter is given as the first argument,
    hooks in the shared repositories will be disabled,
    otherwise they are looked up in the current local repository.
    The \`--all\` parameter on its own will disable running any Githooks
    in the current repository, both existing ones and any future hooks.
    The \`--reset\` parameter is used to undo this, and let hooks run again.
"
        return
    fi

    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    if [ "$1" = "-a" ] || [ "$1" = "--all" ]; then
        git config githooks.disable Y &&
            echo "All existing and future hooks are disabled in the current repository" &&
            return

        echo "! Failed to disable hooks in the current repository" >&2
        exit 1

    elif [ "$1" = "-r" ] || [ "$1" = "--reset" ]; then
        git config --unset githooks.disable

        if ! git config --get githooks.disable; then
            echo "Githooks hook files are not disabled anymore by default" && return
        else
            echo "! Failed to re-enable Githooks hook files" >&2
            exit 1
        fi
    fi

    if ! find_hook_path_to_enable_or_disable "$@"; then
        if [ "$1" = "update" ]; then
            echo "  Did you mean \`git hooks update disable\` ?"
        fi

        exit 1
    fi

    ensure_checksum_file_exists

    find "$HOOK_PATH" -type f -path "*/.githooks/*" | while IFS= read -r HOOK_FILE; do
        if grep -q "disabled> $HOOK_FILE" "${CURRENT_GIT_DIR}/.githooks.checksum" 2>/dev/null; then
            echo "Hook file is already disabled at $HOOK_FILE"
            continue
        fi

        echo "disabled> $HOOK_FILE" >>"${CURRENT_GIT_DIR}/.githooks.checksum"
        echo "Hook file disabled at $HOOK_FILE"
    done
}

#####################################################
# Enables one or more hook files
#   in the current repository.
#
# Returns:
#   1 if the current directory is not a Git repo,
#   0 otherwise
#####################################################
enable_hook() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks enable [--shared] [trigger] [hook-script]
git hooks enable [--shared] [hook-script]
git hooks enable [--shared] [trigger]

    Enables a hook or hooks in the current repository.
    The \`trigger\` parameter should be the name of the Git event if given.
    The \`hook-script\` can be the name of the file to enable, or its
    relative path, or an absolute path, we will try to find it.
    If the \`--shared\` parameter is given as the first argument,
    hooks in the shared repositories will be enabled,
    otherwise they are looked up in the current local repository.
"
        return
    fi

    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    if ! find_hook_path_to_enable_or_disable "$@"; then
        if [ "$1" = "update" ]; then
            echo "  Did you mean \`git hooks update enable\` ?"
        fi

        exit 1
    fi

    ensure_checksum_file_exists

    sed "\\|disabled> $HOOK_PATH|d" "${CURRENT_GIT_DIR}/.githooks.checksum" >"${CURRENT_GIT_DIR}/.githooks.checksum.tmp" &&
        mv "${CURRENT_GIT_DIR}/.githooks.checksum.tmp" "${CURRENT_GIT_DIR}/.githooks.checksum" &&
        echo "Hook file(s) enabled at $HOOK_PATH"
}

#####################################################
# Accept changes to a new or existing but changed
#   hook file by recording its checksum as accepted.
#
# Returns:
#   1 if the current directory is not a Git repo,
#   0 otherwise
#####################################################
accept_changes() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks accept [--shared] [trigger] [hook-script]
git hooks accept [--shared] [hook-script]
git hooks accept [--shared] [trigger]

    Accepts a new hook or changes to an existing hook.
    The \`trigger\` parameter should be the name of the Git event if given.
    The \`hook-script\` can be the name of the file to enable, or its
    relative path, or an absolute path, we will try to find it.
    If the \`--shared\` parameter is given as the first argument,
    hooks in the shared repositories will be accepted,
    otherwise they are looked up in the current local repository.
"
        return
    fi

    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    find_hook_path_to_enable_or_disable "$@" || exit 1

    ensure_checksum_file_exists

    find "$HOOK_PATH" -type f -path "*/.githooks/*" | while IFS= read -r HOOK_FILE; do
        if grep -q "disabled> $HOOK_FILE" "${CURRENT_GIT_DIR}/.githooks.checksum"; then
            echo "Hook file is currently disabled at $HOOK_FILE"
            continue
        fi

        CHECKSUM=$(get_hook_checksum "$HOOK_FILE")

        echo "$CHECKSUM $HOOK_FILE" >>"${CURRENT_GIT_DIR}/.githooks.checksum" &&
            echo "Changes accepted for $HOOK_FILE"
    done
}

#####################################################
# Returns the MD5 checksum of the hook file
#   passed in as the first argument.
#####################################################
get_hook_checksum() {
    # get hash of the hook contents
    if ! MD5_HASH=$(md5 -r "$1" 2>/dev/null); then
        MD5_HASH=$(md5sum "$1" 2>/dev/null)
    fi

    echo "$MD5_HASH" | awk "{ print \$1 }"
}

#####################################################
# Manage settings related to trusted repositories.
#   It allows setting up and clearing marker
#   files and Git configuration.
#
# Returns:
#   1 on failure, 0 otherwise
#####################################################
manage_trusted_repo() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks trust
git hooks trust [revoke]
git hooks trust [delete]
git hooks trust [forget]

    Sets up, or reverts the trusted setting for the local repository.
    When called without arguments, it marks the local repository as trusted.
    The \`revoke\` argument resets the already accepted trust setting,
    and the \`delete\` argument also deletes the trusted marker.
    The \`forget\` option unsets the trust setting, asking for accepting
    it again next time, if the repository is marked as trusted.
"
        return
    fi

    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    if [ -z "$1" ]; then
        mkdir -p .githooks &&
            touch .githooks/trust-all &&
            git config githooks.trust.all Y &&
            echo "The current repository is now trusted." &&
            echo_if_non_bare_repo "  Do not forget to commit and push the trust marker!" &&
            return

        echo "! Failed to mark the current repository as trusted" >&2
        exit 1
    fi

    if [ "$1" = "forget" ]; then
        if [ -z "$(git config --local --get githooks.trust.all)" ]; then
            echo "The current repository does not have trust settings."
            return
        elif git config --unset githooks.trust.all; then
            echo "The current repository is no longer trusted."
            return
        else
            echo "! Failed to revoke the trusted setting" >&2
            exit 1
        fi

    elif [ "$1" = "revoke" ] || [ "$1" = "delete" ]; then
        if git config githooks.trust.all N; then
            echo "The current repository is no longer trusted."
        else
            echo "! Failed to revoke the trusted setting" >&2
            exit 1
        fi

        if [ "$1" = "revoke" ]; then
            return
        fi
    fi

    if [ "$1" = "delete" ] || [ -f .githooks/trust-all ]; then
        rm -rf .githooks/trust-all &&
            echo "The trust marker is removed from the repository." &&
            echo_if_non_bare_repo "  Do not forget to commit and push the change!" &&
            return

        echo "! Failed to delete the trust marker" >&2
        exit 1
    fi

    echo "! Unknown subcommand: $1" >&2
    echo "  Run \`git hooks trust help\` to see the available options." >&2
    exit 1
}

#####################################################
# Lists the hook files in the current
#   repository along with their current state.
#
# Returns:
#   1 if the current directory is not a Git repo,
#   0 otherwise
#####################################################
list_hooks() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks list [type]

    Lists the active hooks in the current repository along with their state.
    If \`type\` is given, then it only lists the hooks for that trigger event.
    This command needs to be run at the root of a repository.
"
        return
    fi

    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    if [ -n "$*" ]; then
        LIST_TYPES="$*"
        WARN_NOT_FOUND="1"
    else
        LIST_TYPES="
        applypatch-msg pre-applypatch post-applypatch
        pre-commit prepare-commit-msg commit-msg post-commit
        pre-rebase post-checkout post-merge pre-push
        pre-receive update post-receive post-update
        push-to-checkout pre-auto-gc post-rewrite sendemail-validate"
    fi

    for LIST_TYPE in $LIST_TYPES; do
        LIST_OUTPUT=""

        # non-Githooks hook file
        if [ -x "${CURRENT_GIT_DIR}/hooks/${LIST_TYPE}.replaced.githook" ]; then
            ITEM_STATE=$(get_hook_state "${CURRENT_GIT_DIR}/hooks/${LIST_TYPE}.replaced.githook")
            LIST_OUTPUT="$LIST_OUTPUT
  - $LIST_TYPE (previous / file / ${ITEM_STATE})"
        fi

        # global shared hooks
        SHARED_REPOS_LIST=$(git config --global --get githooks.shared)
        for SHARED_ITEM in $(list_hooks_in_shared_repos "$LIST_TYPE"); do
            if [ -d "$SHARED_ITEM" ]; then
                for LIST_ITEM in "$SHARED_ITEM"/*; do
                    ITEM_NAME=$(basename "$LIST_ITEM")
                    ITEM_STATE=$(get_hook_state "$LIST_ITEM")
                    LIST_OUTPUT="$LIST_OUTPUT
  - $ITEM_NAME (${ITEM_STATE} / shared:global)"
                done

            elif [ -f "$SHARED_ITEM" ]; then
                ITEM_STATE=$(get_hook_state "$SHARED_ITEM")
                LIST_OUTPUT="$LIST_OUTPUT
  - $LIST_TYPE (file / ${ITEM_STATE} / shared:global)"
            fi
        done

        # local shared hooks
        if [ -f "$(pwd)/.githooks/.shared" ]; then
            SHARED_REPOS_LIST=$(grep -E "^[^#].+$" <"$(pwd)/.githooks/.shared")
            for SHARED_ITEM in $(list_hooks_in_shared_repos "$LIST_TYPE"); do
                if [ -d "$SHARED_ITEM" ]; then
                    for LIST_ITEM in "$SHARED_ITEM"/*; do
                        ITEM_NAME=$(basename "$LIST_ITEM")
                        ITEM_STATE=$(get_hook_state "$LIST_ITEM")
                        LIST_OUTPUT="$LIST_OUTPUT
  - $ITEM_NAME (${ITEM_STATE} / shared:local)"
                    done

                elif [ -f "$SHARED_ITEM" ]; then
                    ITEM_STATE=$(get_hook_state "$SHARED_ITEM")
                    LIST_OUTPUT="$LIST_OUTPUT
  - $LIST_TYPE (file / ${ITEM_STATE} / shared:local)"
                fi
            done
        fi

        # in the current repository
        if [ -d ".githooks/$LIST_TYPE" ]; then
            for LIST_ITEM in .githooks/"$LIST_TYPE"/*; do
                ITEM_NAME=$(basename "$LIST_ITEM")
                ITEM_STATE=$(get_hook_state "$(pwd)/.githooks/$LIST_TYPE/$ITEM_NAME")
                LIST_OUTPUT="$LIST_OUTPUT
  - $ITEM_NAME (${ITEM_STATE})"
            done

        elif [ -f ".githooks/$LIST_TYPE" ]; then
            ITEM_STATE=$(get_hook_state "$(pwd)/.githooks/$LIST_TYPE")
            LIST_OUTPUT="$LIST_OUTPUT
  - $LIST_TYPE (file / ${ITEM_STATE})"

        fi

        if [ -n "$LIST_OUTPUT" ]; then
            echo "> ${LIST_TYPE}${LIST_OUTPUT}"

        elif [ -n "$WARN_NOT_FOUND" ]; then
            echo "> $LIST_TYPE"
            echo "  No active hooks found"

        fi
    done
}

#####################################################
# Returns the state of hook file
#   in a human-readable format
#   on the standard output.
#####################################################
get_hook_state() {
    if is_repository_disabled; then
        echo "disabled"
    elif is_file_ignored "$1"; then
        echo "ignored"
    elif is_trusted_repo; then
        echo "active / trusted"
    else
        get_hook_enabled_or_disabled_state "$1"
    fi
}

#####################################################
# Checks if Githooks is disabled in the
#   current local repository.
#
# Returns:
#   0 if disabled, 1 otherwise
#####################################################
is_repository_disabled() {
    GITHOOKS_CONFIG_DISABLE=$(git config --get githooks.disable)
    if [ "$GITHOOKS_CONFIG_DISABLE" = "y" ] || [ "$GITHOOKS_CONFIG_DISABLE" = "Y" ]; then
        return 0
    else
        return 1
    fi
}

#####################################################
# Checks if the hook file at ${HOOK_PATH}
#   is ignored and should not be executed.
#
# Returns:
#   0 if ignored, 1 otherwise
#####################################################
is_file_ignored() {
    HOOK_NAME=$(basename "$1")
    IS_IGNORED=""

    # If there are .ignore files, read the list of patterns to exclude.
    ALL_IGNORE_FILE=$(mktemp)
    if [ -f ".githooks/.ignore" ]; then
        cat ".githooks/.ignore" >"$ALL_IGNORE_FILE"
        echo >>"$ALL_IGNORE_FILE"
    fi
    if [ -f ".githooks/${LIST_TYPE}/.ignore" ]; then
        cat ".githooks/${LIST_TYPE}/.ignore" >>"$ALL_IGNORE_FILE"
        echo >>"$ALL_IGNORE_FILE"
    fi

    # Check if the filename matches any of the ignored patterns
    while IFS= read -r IGNORED; do
        if [ -z "$IGNORED" ] || [ "$IGNORED" != "${IGNORED#\#}" ]; then
            continue
        fi

        if [ -z "${HOOK_NAME##$IGNORED}" ]; then
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
# Checks whether the current repository
#   is trusted, and that this is accepted.
#
# Returns:
#   0 if the repo is trusted, 1 otherwise
#####################################################
is_trusted_repo() {
    if [ -f ".githooks/trust-all" ]; then
        TRUST_ALL_CONFIG=$(git config --local --get githooks.trust.all)
        TRUST_ALL_RESULT=$?

        # shellcheck disable=SC2181
        if [ $TRUST_ALL_RESULT -ne 0 ]; then
            return 1
        elif [ $TRUST_ALL_RESULT -eq 0 ] && [ "$TRUST_ALL_CONFIG" = "Y" ]; then
            return 0
        fi
    fi

    return 1
}

#####################################################
# Returns the enabled or disabled state
#   in human-readable format for a hook file
#   passed in as the first argument.
#####################################################
get_hook_enabled_or_disabled_state() {
    HOOK_PATH="$1"

    # get hash of the hook contents
    if ! MD5_HASH=$(md5 -r "$HOOK_PATH" 2>/dev/null); then
        MD5_HASH=$(md5sum "$HOOK_PATH" 2>/dev/null)
    fi
    MD5_HASH=$(echo "$MD5_HASH" | awk "{ print \$1 }")
    CURRENT_HASHES=$(grep "$HOOK_PATH" "${CURRENT_GIT_DIR}/.githooks.checksum" 2>/dev/null)

    # check against the previous hash
    if echo "$CURRENT_HASHES" | grep -q "disabled> $HOOK_PATH" >/dev/null 2>&1; then
        echo "disabled"
    elif ! echo "$CURRENT_HASHES" | grep -q "$MD5_HASH $HOOK_PATH" >/dev/null 2>&1; then
        if [ -z "$CURRENT_HASHES" ]; then
            echo "pending / new"
        else
            echo "pending / changed"
        fi
    else
        echo "active"
    fi
}

#####################################################
# List the shared hooks from the
#  $INSTALL_DIR/shared directory.
#
# Returns the list of paths to the hook files
#   in the shared hook repositories found locally.
#####################################################
list_hooks_in_shared_repos() {
    if [ ! -d "$INSTALL_DIR/shared" ]; then
        return
    fi

    SHARED_LIST_TYPE="$1"

    for SHARED_ROOT in "$INSTALL_DIR/shared/"*; do
        if [ ! -d "$SHARED_ROOT" ]; then
            continue
        fi

        REMOTE_URL=$(git -C "$SHARED_ROOT" config --get remote.origin.url)
        ACTIVE_REPO=$(echo "$SHARED_REPOS_LIST" | grep -o "$REMOTE_URL")
        if [ "$ACTIVE_REPO" != "$REMOTE_URL" ]; then
            continue
        fi

        if [ -e "${SHARED_ROOT}/.githooks/${SHARED_LIST_TYPE}" ]; then
            echo "${SHARED_ROOT}/.githooks/${SHARED_LIST_TYPE}"
        elif [ -e "${SHARED_ROOT}/${LIST_TYPE}" ]; then
            echo "${SHARED_ROOT}/${LIST_TYPE}"
        fi
    done
}

#####################################################
# Manages the shared hook repositories set either
#   globally, or locally within the repository.
# Changes the \`githooks.shared\` global Git
#   configuration, or the contents of the
#   \`.githooks/.shared\` file in the local
#   Git repository.
#
# Returns:
#   0 on success, 1 on failure (exit code)
#####################################################
manage_shared_hook_repos() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks shared [add|remove] [--global|--local] <git-url>
git hooks shared clear [--global|--local|--all]
git hooks shared purge
git hooks shared list [--global|--local|--all] [--with-url]
git hooks shared [update|pull]

    Manages the shared hook repositories set either globally, or locally within the repository.
    The \`add\` or \`remove\` subcommands adds or removes an item, given as \`git-url\` from the list.
    If \`--global\` is given, then the \`githooks.shared\` global Git configuration is modified, or if the
    \`--local\` option (default) is set, the \`.githooks/.shared\` file is modified in the local repository.
    The \`clear\` subcommand deletes every item on either the global or the local list,
    or both when the \`--all\` option is given.
    The \`purge\` subcommand deletes the shared hook repositories already pulled locally.
    The \`list\` subcommand list the global, local or all (default) shared hooks repositories,
    and optionally prints the Git URL for them, when the \`--with-url\` option is used.
    The \`update\` or \`pull\` subcommands update all the shared repositories, both global and local, either by
    running \`git pull\` on existing ones or \`git clone\` on new ones.
"
        return
    fi

    if [ "$1" = "update" ] || [ "$1" = "pull" ]; then
        update_shared_hook_repos
        return
    fi

    if [ "$1" = "clear" ]; then
        shift
        clear_shared_hook_repos "$@"
        return
    fi

    if [ "$1" = "purge" ]; then
        [ -w "$INSTALL_DIR/shared" ] &&
            rm -rf "$INSTALL_DIR/shared" &&
            echo "All existing shared hook repositories have been deleted locally" &&
            return

        echo "! Cannot delete existing shared hook repositories locally (maybe there is none)" >&2
        exit 1
    fi

    if [ "$1" = "list" ]; then
        shift
        list_shared_hook_repos "$@"
        return
    fi

    if [ "$1" = "add" ]; then
        shift
        add_shared_hook_repo "$@"
        return
    fi

    if [ "$1" = "remove" ]; then
        shift
        remove_shared_hook_repo "$@"
        return
    fi

    echo "! Unknown subcommand: \`$1\`" >&2
    exit 1
}

#####################################################
# Adds the URL of a new shared hook repository to
#   the global or local list.
#####################################################
add_shared_hook_repo() {
    SET_SHARED_GLOBAL=
    SHARED_REPO_URL=

    case "$1" in
    "--global")
        SET_SHARED_GLOBAL=1
        SHARED_REPO_URL="$2"
        ;;
    "--local")
        SET_SHARED_GLOBAL=
        SHARED_REPO_URL="$2"
        ;;
    *)
        SHARED_REPO_URL="$1"
        ;;
    esac

    if [ -z "$SHARED_REPO_URL" ]; then
        echo "! Usage: \`git hooks shared add [--global|--local] <git-url>\`" >&2
        exit 1
    fi

    if [ -n "$SET_SHARED_GLOBAL" ]; then
        CURRENT_LIST=$(git config --global --get githooks.shared)

        if [ -n "$CURRENT_LIST" ]; then
            NEW_LIST="${CURRENT_LIST},${SHARED_REPO_URL}"
        else
            NEW_LIST="$SHARED_REPO_URL"
        fi

        git config --global githooks.shared "$NEW_LIST" &&
            echo "The new shared hook repository is successfully added" &&
            return

        echo "! Failed to add the new shared hook repository" >&2
        exit 1

    else
        if ! is_running_in_git_repo_root; then
            echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
            exit 1
        fi

        mkdir -p "$(pwd)/.githooks"

        [ -f "$(pwd)/.githooks/.shared" ] &&
            echo "" >>"$(pwd)/.githooks/.shared"

        echo "# Added on $(date)" >>"$(pwd)/.githooks/.shared" &&
            echo "$SHARED_REPO_URL" >>"$(pwd)/.githooks/.shared" &&
            echo "The new shared hook repository is successfully added" &&
            echo_if_non_bare_repo "  Do not forget to commit the change!" &&
            return

        echo "! Failed to add the new shared hook repository" >&2
        exit 1

    fi
}

#####################################################
# Removes the URL of a new shared hook repository to
#   the global or local list.
#####################################################
remove_shared_hook_repo() {
    SET_SHARED_GLOBAL=
    SHARED_REPO_URL=

    case "$1" in
    "--global")
        SET_SHARED_GLOBAL=1
        SHARED_REPO_URL="$2"
        ;;
    "--local")
        SET_SHARED_GLOBAL=
        SHARED_REPO_URL="$2"
        ;;
    *)
        SHARED_REPO_URL="$1"
        ;;
    esac

    if [ -z "$SHARED_REPO_URL" ]; then
        echo "! Usage: \`git hooks shared remove [--global|--local] <git-url>\`" >&2
        exit 1
    fi

    if [ -n "$SET_SHARED_GLOBAL" ]; then
        CURRENT_LIST=$(git config --global --get githooks.shared)
        NEW_LIST=""

        IFS="$IFS_COMMA_NEWLINE"

        for SHARED_REPO_ITEM in $CURRENT_LIST; do
            unset IFS
            if [ "$SHARED_REPO_ITEM" = "$SHARED_REPO_URL" ]; then
                continue
            fi

            if [ -z "$NEW_LIST" ]; then
                NEW_LIST="$SHARED_REPO_ITEM"
            else
                NEW_LIST="${NEW_LIST},${SHARED_REPO_ITEM}"
            fi
            IFS="$IFS_COMMA_NEWLINE"
        done

        unset IFS

        if [ -z "$NEW_LIST" ]; then
            clear_shared_hook_repos "--global" && return || exit 1
        fi

        git config --global githooks.shared "$NEW_LIST" &&
            echo "The list of shared hook repositories is successfully changed" &&
            return

        echo "! Failed to remove a shared hook repository" >&2
        exit 1

    else
        if ! is_running_in_git_repo_root; then
            echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
            exit 1
        fi

        CURRENT_LIST=$(grep -E "^[^#].+$" <"$(pwd)/.githooks/.shared")
        NEW_LIST=""

        IFS="$IFS_COMMA_NEWLINE"

        for SHARED_REPO_ITEM in $CURRENT_LIST; do
            unset IFS
            if [ "$SHARED_REPO_ITEM" = "$SHARED_REPO_URL" ]; then
                continue
            fi

            if [ -z "$NEW_LIST" ]; then
                NEW_LIST="$SHARED_REPO_ITEM"
            else
                NEW_LIST="${NEW_LIST}
${SHARED_REPO_ITEM}"
            fi
            IFS="$IFS_COMMA_NEWLINE"
        done

        unset IFS

        if [ -z "$NEW_LIST" ]; then
            clear_shared_hook_repos "--local" && return || exit 1
        fi

        echo "$NEW_LIST" >"$(pwd)/.githooks/.shared" &&
            echo "The list of shared hook repositories is successfully changed" &&
            echo_if_non_bare_repo "  Do not forget to commit the change!" &&
            return

        echo "! Failed to remove a shared hook repository" >&2
        exit 1

    fi
}

#####################################################
# Clears the list of shared hook repositories
#   from the global or local list, or both.
#####################################################
clear_shared_hook_repos() {
    CLEAR_GLOBAL_REPOS=
    CLEAR_LOCAL_REPOS=

    case "$1" in
    "--global")
        CLEAR_GLOBAL_REPOS=1
        ;;
    "--local")
        CLEAR_LOCAL_REPOS=1
        ;;
    "--all")
        CLEAR_GLOBAL_REPOS=1
        CLEAR_LOCAL_REPOS=1
        ;;
    *)
        echo "! One of the following must be used:" >&2
        echo "    \$ git hooks shared clear --global" >&2
        echo "    \$ git hooks shared clear --local" >&2
        echo "    \$ git hooks shared clear --all" >&2
        exit 1
        ;;
    esac

    if [ -n "$CLEAR_GLOBAL_REPOS" ] && [ -n "$(git config --global --get githooks.shared)" ]; then
        git config --global --unset githooks.shared &&
            echo "Global shared hook repository list cleared" ||
            CLEAR_REPOS_FAILED=1
    fi

    if [ -n "$CLEAR_LOCAL_REPOS" ] && [ -f "$(pwd)/.githooks/.shared" ]; then
        rm -f "$(pwd)/.githooks/.shared" &&
            echo "Local shared hook repository list cleared" ||
            CLEAR_REPOS_FAILED=1
    fi

    if [ -n "$CLEAR_REPOS_FAILED" ]; then
        echo "! There were some problems clearing the shared hook repository list" >&2
        exit 1
    fi
}

#####################################################
# Prints the list of shared hook repositories,
#   along with their Git URLs optionally, from
#   the global or local list, or both.
#####################################################
list_shared_hook_repos() {
    LIST_GLOBAL=1
    LIST_LOCAL=1
    LIST_WITH_URL=

    for ARG in "$@"; do
        case "$ARG" in
        "--global")
            LIST_LOCAL=
            ;;
        "--local")
            LIST_GLOBAL=
            ;;
        "--all")
            # leave both list options on
            ;;
        "--with-url")
            LIST_WITH_URL=1
            ;;
        *)
            echo "! Unknown list option: $ARG" >&2
            exit 1
            ;;
        esac
    done

    if [ -n "$LIST_GLOBAL" ]; then
        echo "Global shared hook repositories:"

        if [ -z "$(git config --global --get githooks.shared)" ]; then
            echo "  - None"
        else

            IFS="$IFS_COMMA_NEWLINE"
            for LIST_ITEM in $(git config --global --get githooks.shared); do
                unset IFS

                set_shared_root "$LIST_ITEM"
                if [ -d "$SHARED_ROOT/.git" ]; then
                    if [ "$(git -C "$SHARED_ROOT" config --get remote.origin.url)" = "$LIST_ITEM" ]; then
                        LIST_ITEM_STATE="active"
                    else
                        LIST_ITEM_STATE="invalid"
                    fi
                else
                    LIST_ITEM_STATE="pending"
                fi

                if [ -n "$LIST_WITH_URL" ]; then
                    echo "  - $NORMALIZED_NAME ($LIST_ITEM_STATE)
      url: $LIST_ITEM"
                else
                    echo "  - $NORMALIZED_NAME ($LIST_ITEM_STATE)"
                fi

                IFS="$IFS_COMMA_NEWLINE"
            done
            unset IFS
        fi
    fi

    if [ -n "$LIST_LOCAL" ]; then
        echo "Local shared hook repositories:"

        if ! is_running_in_git_repo_root; then
            echo "  - Current folder does not seem to be a Git repository"
            exit 1
        elif [ ! -f "$(pwd)/.githooks/.shared" ]; then
            echo "  - None"
        else
            SHARED_REPOS_LIST=$(grep -E "^[^#].+$" <"$(pwd)/.githooks/.shared")

            IFS="$IFS_COMMA_NEWLINE"
            echo "$SHARED_REPOS_LIST" | while read -r LIST_ITEM; do
                unset IFS

                set_shared_root "$LIST_ITEM"

                if [ -d "$SHARED_ROOT/.git" ]; then
                    if [ "$(git -C "$SHARED_ROOT" config --get remote.origin.url)" = "$LIST_ITEM" ]; then
                        LIST_ITEM_STATE="active"
                    else
                        LIST_ITEM_STATE="invalid"
                    fi
                else
                    LIST_ITEM_STATE="pending"
                fi

                if [ -n "$LIST_WITH_URL" ]; then
                    echo "  - $NORMALIZED_NAME ($LIST_ITEM_STATE)
      url: $LIST_ITEM"
                else
                    echo "  - $NORMALIZED_NAME ($LIST_ITEM_STATE)"
                fi

                IFS="$IFS_COMMA_NEWLINE"
            done
            unset IFS
        fi
    fi

}

#####################################################
# Updates the configured shared hook repositories.
#
# Returns:
#   None
#####################################################
update_shared_hook_repos() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks pull

    Updates the shared repositories found either
    in the global Git configuration, or in the
    \`.githooks/.shared\` file in the local repository.

> Please use \`git hooks shared pull\` instead, this version is now deprecated.
"
        return
    fi

    SHARED_HOOKS=$(git config --global --get githooks.shared)
    if [ -n "$SHARED_HOOKS" ]; then
        update_shared_hooks_in "$SHARED_HOOKS"
    fi

    if [ -f "$(pwd)/.githooks/.shared" ]; then
        SHARED_HOOKS=$(grep -E "^[^#].+$" <"$(pwd)/.githooks/.shared")
        update_shared_hooks_in "$SHARED_HOOKS"
    fi

    echo "Finished"
}

#####################################################
# Sets the SHARED_ROOT and NORMALIZED_NAME
#   for the shared hook repo url `$1`.
#
# Returns:
#   0 when successfully finished, 1 otherwise
#####################################################
set_shared_root() {
    NORMALIZED_NAME=$(echo "$1" |
        sed -E "s#.*[:/](.+/.+)\\.git#\\1#" |
        sed -E "s/[^a-zA-Z0-9]/_/g")
    SHARED_ROOT="$INSTALL_DIR/shared/$NORMALIZED_NAME"
}

#####################################################
# Updates the shared hooks repositories
#   on the list passed in on the first argument.
#####################################################
update_shared_hooks_in() {
    SHARED_REPOS_LIST="$1"

    # split on comma and newline
    IFS="$IFS_COMMA_NEWLINE"

    for SHARED_REPO in $SHARED_REPOS_LIST; do
        unset IFS

        mkdir -p "$INSTALL_DIR/shared"

        set_shared_root "$SHARED_REPO"

        if [ -d "$SHARED_ROOT/.git" ]; then
            echo "* Updating shared hooks from: $SHARED_REPO"
            PULL_OUTPUT="$(git -C "$SHARED_ROOT" --work-tree="$SHARED_ROOT" --git-dir="$SHARED_ROOT/.git" -c core.hooksPath=/dev/null pull 2>&1)"
            # shellcheck disable=SC2181
            if [ $? -ne 0 ]; then
                echo "! Update failed, git pull output:" >&2
                echo "$PULL_OUTPUT" >&2
            fi
        else
            echo "* Retrieving shared hooks from: $SHARED_REPO"
            [ -d "$SHARED_ROOT" ] && rm -rf "$SHARED_ROOT"
            CLONE_OUTPUT=$(git -c core.hooksPath=/dev/null clone "$SHARED_REPO" "$SHARED_ROOT" 2>&1)
            # shellcheck disable=SC2181
            if [ $? -ne 0 ]; then
                echo "! Clone failed, git clone output:" >&2
                echo "$CLONE_OUTPUT" >&2
            fi
        fi

        IFS="$IFS_COMMA_NEWLINE"
    done

    unset IFS
}

#####################################################
# Executes an ondemand installation
#   of the latest Githooks version.
#
# Returns:
#   1 if the installation fails,
#   0 otherwise
#####################################################
run_ondemand_installation() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks install [--global]

    Installs the Githooks hooks into the current repository.
    If the \`--global\` flag is given, it executes the installation
    globally, including the hook templates for future repositories.
"
        return
    fi

    if [ "$1" = "--global" ]; then
        IS_SINGLE_REPO="no"
    else
        IS_SINGLE_REPO="yes"
    fi

    echo "Fetching the install script ..."

    if ! fetch_latest_install_script; then
        echo "! Failed to fetch the latest install script" >&2
        echo "  You can retry manually using one of the alternative methods," >&2
        echo "  see them here: https://github.com/rycus86/githooks#installation" >&2
        exit 1
    fi

    read_latest_version_number

    echo "  Githooks install script downloaded: Version $LATEST_VERSION"
    echo

    if ! execute_install_script; then
        echo "! Failed to execute the installation" >&2
        exit 1
    fi
}

#####################################################
# Executes an ondemand uninstallation of Githooks.
#
# Returns:
#   1 if the uninstallation fails,
#   0 otherwise
#####################################################
run_ondemand_uninstallation() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks uninstall [--global]

    Uninstalls the Githooks hooks from the current repository.
    If the \`--global\` flag is given, it executes the uninstallation
    globally, including the hook templates and all local repositories.
"
        return
    fi

    UNINSTALL_ARGS="--local"
    if [ "$1" = "--global" ]; then
        UNINSTALL_ARGS="--global"
    elif [ -n "$1" ]; then
        echo "! Invalid argument: \`$1\`" >&2 && exit 1
    fi

    echo "Fetching the uninstall script ..."

    if ! fetch_latest_uninstall_script; then
        echo "! Failed to fetch the latest uninstall script" >&2
        echo "  You can retry manually using one of the alternative methods," >&2
        echo "  see them here: https://github.com/rycus86/githooks#uninstalling" >&2
        exit 1
    fi

    if ! execute_uninstall_script $UNINSTALL_ARGS; then
        echo "! Failed to execute the uninstallation" >&2
        exit 1
    fi
}

#####################################################
# Executes an update check, and potentially
#   the installation of the latest version.
#
# Returns:
#   1 if the latest version cannot be retrieved,
#   0 otherwise
#####################################################
run_update_check() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks update [force]
git hooks update [enable|disable]

    Executes an update check for a newer Githooks version.
    If it finds one, or if \`force\` was given, the downloaded
    install script is executed for the latest version.
    The \`enable\` and \`disable\` options enable or disable
    the automatic checks that would normally run daily
    after a successful commit event.
"
        return
    fi

    if [ "$1" = "enable" ]; then
        git config --global githooks.autoupdate.enabled Y &&
            echo "Automatic update checks have been enabled" &&
            return

        echo "! Failed to enable automatic updates" >&2 && exit 1

    elif [ "$1" = "disable" ]; then
        git config --global githooks.autoupdate.enabled N &&
            echo "Automatic update checks have been disabled" &&
            return

        echo "! Failed to disable automatic updates" >&2 && exit 1

    elif [ -n "$1" ] && [ "$1" != "force" ]; then
        echo "! Invalid operation: \`$1\`" >&2 && exit 1

    fi

    record_update_time

    echo "Checking for updates ..."

    if ! fetch_latest_install_script; then
        echo "! Failed to check for updates: cannot fetch updated install script"
        exit 1
    fi

    read_latest_version_number

    if [ "$1" != "force" ]; then
        if ! is_update_available; then
            echo "  Githooks is already on the latest version"
            return
        fi
    fi

    echo "  There is a new Githooks update available: Version $LATEST_VERSION"
    echo

    read_single_repo_information

    if ! execute_install_script; then
        echo "! Failed to execute the installation"
        print_update_disable_info
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
# Call a script "$1". If it is not executable
# call it as a shell script.
#
# Returns:
#   Error code of the script.
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
# Downloads a file "$1" with `wget` or `curl`
#
# Returns:
#   0 if download succeeded, 1 otherwise
#####################################################
download_file() {
    DOWNLOAD_FILE="$1"
    OUTPUT_FILE="$2"
    DOWNLOAD_APP=$(get_tool_script "download")

    if [ "$DOWNLOAD_APP" != "" ]; then
        echo "  Using App at \`$DOWNLOAD_APP\`"
        # Use the external download app for downloading the file
        call_script "$DOWNLOAD_APP" "$DOWNLOAD_FILE" "$OUTPUT_FILE"
    else
        # The main update url.
        MAIN_DOWNLOAD_URL="https://raw.githubusercontent.com/rycus86/githooks/master"

        # Default implementation
        DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/$DOWNLOAD_FILE"

        echo "  Download $DOWNLOAD_URL ..."
        if curl --version >/dev/null 2>&1; then
            curl -fsSL "$DOWNLOAD_URL" -o "$OUTPUT_FILE" >/dev/null 2>&1
        elif wget --version >/dev/null 2>&1; then
            wget -O "$OUTPUT_FILE" "$DOWNLOAD_URL" >/dev/null 2>&1
        else
            echo "! Cannot download file \`$DOWNLOAD_URL\` - needs either curl or wget"
            return 1
        fi
    fi

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Cannot download file \`$DOWNLOAD_FILE\` - command failed"
        return 1
    fi
    return 0
}

#####################################################
# Loads the contents of the latest install
#   script into a file ${INSTALL_SCRIPT}.
#
# Sets the ${INSTALL_SCRIPT} variable
#
# Returns:
#   1 if failed the load the script, 0 otherwise
#####################################################
fetch_latest_install_script() {
    INSTALL_SCRIPT="$(mktemp)"
    if ! download_file "install.sh" "$INSTALL_SCRIPT"; then
        return 1
    fi
}

#####################################################
# Loads the contents of the latest uninstall
#   script into a file ${UNINSTALL_SCRIPT}.
#
# Sets the ${UNINSTALL_SCRIPT} variable
#
# Returns:
#   1 if failed the load the script, 0 otherwise
#####################################################
fetch_latest_uninstall_script() {
    UNINSTALL_SCRIPT="$(mktemp)"
    if ! download_file "uninstall.sh" "$UNINSTALL_SCRIPT"; then
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
read_latest_version_number() {
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
#   1 if they were, 0 otherwise
#####################################################
is_single_repo() {
    [ "$IS_SINGLE_REPO" = "yes" ] || return 1
}

#####################################################
# Performs the installation of the previously
#   fetched install script.
#
# Returns:
#   0 if the installation was successful, 1 otherwise
#####################################################
execute_install_script() {
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
# Performs the uninstallation of the previously
#   fetched uninstall script.
#
# Returns:
#   0 if the uninstallation was successful,
#   1 otherwise
#####################################################
execute_uninstall_script() {
    if [ $# -ne 0 ]; then
        if sh -s -- "$@" <"$UNINSTALL_SCRIPT"; then
            return 0
        fi
    else
        if sh <"$UNINSTALL_SCRIPT"; then
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

#####################################################
# Adds or updates the Githooks README in
#   the current local repository.
#
# Returns:
#   1 on failure, 0 otherwise
#####################################################
manage_readme_file() {
    case "$1" in
    "add")
        FORCE_README=""
        ;;
    "update")
        FORCE_README="y"
        ;;
    *)
        print_help_header
        echo "
git hooks readme [add|update]

    Adds or updates the Githooks README in the \`.githooks\` folder.
    If \`add\` is used, it checks first if there is a README file already.
    With \`update\`, the file is always updated, creating it if necessary.
    This command needs to be run at the root of a repository.
"
        if [ "$1" = "help" ]; then
            exit 0
        else
            exit 1
        fi
        ;;
    esac

    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    if [ -f .githooks/README.md ] && [ "$FORCE_README" != "y" ]; then
        echo "! This repository already seems to have a Githooks README." >&2
        echo "  If you would like to replace it with the latest one, please run \`git hooks readme update\`" >&2
        exit 1
    fi

    if ! fetch_latest_readme; then
        exit 1
    fi

    mkdir -p "$(pwd)/.githooks" &&
        cat "$README_FILE" >"$(pwd)/.githooks/README.md" &&
        echo "The README file is updated." &&
        echo_if_non_bare_repo "  Do not forget to commit and push it!" ||
        echo "! Failed to update the README file in the current repository" >&2
}

#####################################################
# Loads the contents of the latest Githooks README
#   into a variable.
#
# Sets the ${README_FILE} variable
#
# Returns:
#   1 if failed the load the contents, 0 otherwise
#####################################################
fetch_latest_readme() {
    README_FILE="$(mktemp)"
    if ! download_file ".githooks/README.md" "$README_FILE"; then
        echo "! Failed to fetch the latest README" >&2
        return 1
    fi
}

#####################################################
# Adds or updates Githooks ignore files in
#   the current local repository.
#
# Returns:
#   1 on failure, 0 otherwise
#####################################################
manage_ignore_files() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks ignore [pattern...]
git hooks ignore [trigger] [pattern...]

    Adds new file name patterns to the Githooks \`.ignore\` file, either
    in the main \`.githooks\` folder, or in the Git event specific one.
    Note, that it may be required to surround the individual pattern
    parameters with single quotes to avoid expanding or splitting them.
    The \`trigger\` parameter should be the name of the Git event if given.
    This command needs to be run at the root of a repository.
"
        return
    fi

    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    TRIGGER_TYPES="
        applypatch-msg pre-applypatch post-applypatch
        pre-commit prepare-commit-msg commit-msg post-commit
        pre-rebase post-checkout post-merge pre-push
        pre-receive update post-receive post-update
        push-to-checkout pre-auto-gc post-rewrite sendemail-validate"

    TARGET_DIR="$(pwd)/.githooks"

    for TRIGGER_TYPE in $TRIGGER_TYPES; do
        if [ "$1" = "$TRIGGER_TYPE" ]; then
            TARGET_DIR="$(pwd)/.githooks/$TRIGGER_TYPE"
            shift
            break
        fi
    done

    if [ -z "$1" ]; then
        manage_ignore_files "help"
        echo "! Missing pattern parameter" >&2
        exit 1
    fi

    if ! mkdir -p "$TARGET_DIR" && touch "$TARGET_DIR/.ignore"; then
        echo "! Failed to prepare the ignore file at $TARGET_DIR/.ignore" >&2
        exit 1
    fi

    [ -f "$TARGET_DIR/.ignore" ] &&
        echo "" >>"$TARGET_DIR/.ignore"

    for PATTERN in "$@"; do
        if ! echo "$PATTERN" >>"$TARGET_DIR/.ignore"; then
            echo "! Failed to update the ignore file at $TARGET_DIR/.ignore" >&2
            exit 1
        fi
    done

    echo "The ignore file at $TARGET_DIR/.ignore is updated"
    echo_if_non_bare_repo "  Do not forget to commit the changes!"
}

#####################################################
# Manages various Githooks settings,
#   that is stored in Git configuration.
#
# Returns:
#   1 on failure, 0 otherwise
#####################################################
manage_configuration() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks config list [--global|--local]

    Lists the Githooks related settings of the Githooks configuration.
    Can be either global or local configuration, or both by default.

git hooks config [set|reset|print] disable

    Disables running any Githooks files in the current repository,
    when the \`set\` option is used.
    The \`reset\` option clears this setting.
    The \`print\` option outputs the current setting.
    This command needs to be run at the root of a repository.

git hooks config [set|reset|print] single

    Marks the current local repository to be managed as a single Githooks
    installation, or clears the marker, with \`set\` and \`reset\` respectively.
    The \`print\` option outputs the current setting of it.
    This command needs to be run at the root of a repository.

git hooks config set search-dir <path>
git hooks config [reset|print] search-dir

    Changes the previous search directory setting used during installation.
    The \`set\` option changes the value, and the \`reset\` option clears it.
    The \`print\` option outputs the current setting of it.

git hooks config set shared <git-url...>
git hooks config [reset|print] shared

    Updates the list of global shared hook repositories when
    the \`set\` option is used, which accepts multiple <git-url> arguments,
    each containing a clone URL of a hook repository.
    The \`reset\` option clears this setting.
    The \`print\` option outputs the current setting.

git hooks config [accept|deny|reset|print] trusted

    Accepts changes to all existing and new hooks in the current repository
    when the trust marker is present and the \`set\` option is used.
    The \`deny\` option marks the repository as
    it has refused to trust the changes, even if the trust marker is present.
    The \`reset\` option clears this setting.
    The \`print\` option outputs the current setting.
    This command needs to be run at the root of a repository.

git hooks config [enable|disable|reset|print] update

    Enables or disables automatic update checks with
    the \`enable\` and \`disable\` options respectively.
    The \`reset\` option clears this setting.
    The \`print\` option outputs the current setting.

git hooks config [reset|print] update-time

    Resets the last Githooks update time with the \`reset\` option,
    causing the update check to run next time if it is enabled.
    Use \`git hooks update [enable|disable]\` to change that setting.
    The \`print\` option outputs the current value of it.

git hooks config [enable|disable|print] fail-on-non-existing-shared-hooks [--global|--local]

Enable or disable failing hooks with an error when any
shared hooks configured in \`.shared\` are missing,
which usually means \`git hooks update\` has not been called yet.

git hooks config [yes|no|reset|print] delete-detected-lfs-hooks

By default, detected LFS hooks during install are disabled and backed up.
The \`yes\` option remembers to always delete these hooks. 
The \`no\` option remembers the default behavior.
The decision is reset with \`reset\` to the default behavior. 
The \`print\` option outputs the current behavior.
"
        return
    fi

    CONFIG_OPERATION="$1"

    if [ "$CONFIG_OPERATION" = "list" ]; then
        if [ "$2" = "--local" ] && ! is_running_in_git_repo_root; then
            echo "! Local configuration can only be printed from a Git repository" >&2
            exit 1
        fi

        if [ -z "$2" ]; then
            git config --get-regexp "(^githooks|alias.hooks)" | sort
        else
            git config "$2" --get-regexp "(^githooks|alias.hooks)" | sort
        fi
        exit $?
    fi

    CONFIG_ARGUMENT="$2"

    shift
    shift

    case "$CONFIG_ARGUMENT" in
    "disable")
        config_disable "$CONFIG_OPERATION"
        ;;
    "single")
        config_single_install "$CONFIG_OPERATION"
        ;;
    "search-dir")
        config_search_dir "$CONFIG_OPERATION" "$@"
        ;;
    "shared")
        config_global_shared_hook_repos "$CONFIG_OPERATION" "$@"
        ;;
    "trusted")
        config_trust_all_hooks "$CONFIG_OPERATION"
        ;;
    "update")
        config_update_state "$CONFIG_OPERATION"
        ;;
    "update-time")
        config_update_last_run "$CONFIG_OPERATION"
        ;;
    "fail-on-non-existing-shared-hooks")
        config_fail_on_not_existing_shared_hooks "$CONFIG_OPERATION" "$@"
        ;;
    "delete-detected-lfs-hooks")
        config_delete_detected_lfs_hooks "$CONFIG_OPERATION" "$@"
        ;;
    *)
        manage_configuration "help"
        echo "! Invalid configuration option: \`$CONFIG_ARGUMENT\`" >&2
        exit 1
        ;;
    esac
}

#####################################################
# Manages Githooks disable settings for
#   the current repository.
# Prints or modifies the \`githooks.disable\`
#   local Git configuration.
#####################################################
config_disable() {
    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    if [ "$1" = "set" ]; then
        git config githooks.disable Y
    elif [ "$1" = "reset" ]; then
        git config --unset githooks.disable
    elif [ "$1" = "print" ]; then
        if is_repository_disabled; then
            echo "Githooks is disabled in the current repository"
        else
            echo "Githooks is NOT disabled in the current repository"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages Githooks single installation setting
#   for the current repository.
# Prints or modifies the \`githooks.single.install\`
#   local Git configuration.
#####################################################
config_single_install() {
    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    if [ "$1" = "set" ]; then
        git config --unset githooks.autoupdate.registered
        git config githooks.single.install yes
    elif [ "$1" = "reset" ]; then
        git config --unset githooks.single.install
        # the repository is registered in the next hooks run
    elif [ "$1" = "print" ]; then
        if read_single_repo_information && is_single_repo; then
            echo "The current repository is marked as a single installation"
        else
            echo "The current repository is NOT marked as a single installation"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages previous search directory setting
#   used during Githooks installation.
# Prints or modifies the
#   \`githooks.previous.searchdir\`
#   global Git configuration.
#####################################################
config_search_dir() {
    if [ "$1" = "set" ]; then
        if [ -z "$2" ]; then
            manage_configuration "help"
            echo "! Missing <path> parameter" >&2
            exit 1
        fi

        git config --global githooks.previous.searchdir "$2"
    elif [ "$1" = "reset" ]; then
        git config --global --unset githooks.previous.searchdir
    elif [ "$1" = "print" ]; then
        CONFIG_SEARCH_DIR=$(git config --global --get githooks.previous.searchdir)
        if [ -z "$CONFIG_SEARCH_DIR" ]; then
            echo "No previous search directory is set"
        else
            echo "Search directory is set to: $CONFIG_SEARCH_DIR"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages global shared hook repository list setting.
# Prints or modifies the \`githooks.shared\`
#   global Git configuration.
#####################################################
config_global_shared_hook_repos() {
    if [ "$1" = "set" ]; then
        if [ -z "$2" ]; then
            manage_configuration "help"
            echo "! Missing <git-url> parameter" >&2
            exit 1
        fi

        shift

        NEW_LIST=""
        for SHARED_REPO_ITEM in "$@"; do
            if [ -z "$NEW_LIST" ]; then
                NEW_LIST="$SHARED_REPO_ITEM"
            else
                NEW_LIST="${NEW_LIST},${SHARED_REPO_ITEM}"
            fi
        done

        git config --global githooks.shared "$NEW_LIST"
    elif [ "$1" = "reset" ]; then
        git config --global --unset githooks.shared
    elif [ "$1" = "print" ]; then
        list_shared_hook_repos "--global"
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages the trust-all-hooks setting
#   for the current repository.
# Prints or modifies the \`githooks.trust.all\`
#   local Git configuration.
#####################################################
config_trust_all_hooks() {
    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    if [ "$1" = "accept" ]; then
        git config githooks.trust.all Y
    elif [ "$1" = "deny" ]; then
        git config githooks.trust.all N
    elif [ "$1" = "reset" ]; then
        git config --unset githooks.trust.all
    elif [ "$1" = "print" ]; then
        CONFIG_TRUST_ALL=$(git config --local --get githooks.trust.all)
        if [ "$CONFIG_TRUST_ALL" = "Y" ]; then
            echo "The current repository trusts all hooks automatically"
        elif [ -z "$CONFIG_TRUST_ALL" ]; then
            echo "The current repository does NOT have trust settings"
        else
            echo "The current repository does NOT trust hooks automatically"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`accept\`, \`deny\`, \`reset\` or \`print\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages the automatic update check setting.
# Prints or modifies the
#   \`githooks.autoupdate.enabled\`
#   global Git configuration.
#####################################################
config_update_state() {
    if [ "$1" = "enable" ]; then
        git config --global githooks.autoupdate.enabled Y
    elif [ "$1" = "disable" ]; then
        git config --global githooks.autoupdate.enabled N
    elif [ "$1" = "reset" ]; then
        git config --global --unset githooks.autoupdate.enabled
    elif [ "$1" = "print" ]; then
        CONFIG_UPDATE_ENABLED=$(git config --get githooks.autoupdate.enabled)
        if [ "$CONFIG_UPDATE_ENABLED" = "Y" ]; then
            echo "Automatic update checks are enabled"
        else
            echo "Automatic update checks are NOT enabled"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`enable\`, \`disable\`, \`reset\` or \`print\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages the timestamp for the last update check.
# Prints or modifies the
#   \`githooks.autoupdate.lastrun\`
#   global Git configuration.
#####################################################
config_update_last_run() {
    if [ "$1" = "reset" ]; then
        git config --global --unset githooks.autoupdate.lastrun
    elif [ "$1" = "print" ]; then
        LAST_UPDATE=$(git config --global --get githooks.autoupdate.lastrun)
        if [ -z "$LAST_UPDATE" ]; then
            echo "The update has never run"
        else
            if ! date --date="@${LAST_UPDATE}" 2>/dev/null; then
                if ! date -j -f "%s" "$LAST_UPDATE" 2>/dev/null; then
                    echo "Last update timestamp: $LAST_UPDATE"
                fi
            fi
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`reset\` or \`print\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages the failOnNonExistingSharedHook switch.
# Prints or modifies the
#   `githooks.failOnNonExistingSharedHooks`
#   local or global Git configuration.
#####################################################
config_fail_on_not_existing_shared_hooks() {
    CONFIG="--local"
    if [ -n "$2" ]; then
        if [ "$2" = "--local" ] || [ "$2" = "--global" ]; then
            CONFIG="$2"
        else
            echo "! Invalid option: \`$2\` (use \`--local\` or \`--global\`)" >&2
            exit 1
        fi
    fi

    if [ "$1" = "enable" ]; then
        if ! git config "$CONFIG" githooks.failOnNonExistingSharedHooks "true"; then
            echo "! Failed to enable \`fail-on-non-existing-shared-hooks\`" >&2
            exit 1
        fi

        echo "Failing on not existing shared hooks is enabled"

    elif [ "$1" = "disable" ]; then
        if ! git config "$CONFIG" githooks.failOnNonExistingSharedHooks "false"; then
            echo "! Failed to disable \`fail-on-non-existing-shared-hooks\`" >&2
            exit 1
        fi

        echo "Failing on not existing shared hooks is disabled"

    elif [ "$1" = "print" ]; then
        FAIL_ON_NOT_EXISTING=$(git config "$CONFIG" --get githooks.failOnNonExistingSharedHooks)
        if [ "$FAIL_ON_NOT_EXISTING" = "true" ]; then
            echo "Failing on not existing shared hooks is enabled"
        else
            # default also if it does not exist
            echo "Failing on not existing shared hooks is disabled"
        fi

    else
        echo "! Invalid operation: \`$1\` (use \`enable\`, \`disable\` or \`print\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages the deleteDetectedLFSHooks default bahavior.
# Modifies or prints
#   `githooks.deleteDetectedLFSHooks`
#   global Git configuration.
#####################################################
config_delete_detected_lfs_hooks() {
    if [ "$1" = "yes" ]; then
        git config --global githooks.deleteDetectedLFSHooks "a"
        config_delete_detected_lfs_hooks "print"
    elif [ "$1" = "no" ]; then
        git config --global githooks.deleteDetectedLFSHooks "n"
        config_delete_detected_lfs_hooks "print"
    elif [ "$1" = "reset" ]; then
        git config --global --unset githooks.deleteDetectedLFSHooks
        config_delete_detected_lfs_hooks "print"
    elif [ "$1" = "print" ]; then
        VALUE=$(git config --global githooks.deleteDetectedLFSHooks)
        if [ "$VALUE" = "Y" ]; then
            echo "Detected LFS hooks are by default deleted"
        else
            echo "Detected LFS hooks are by default disabled and backed up"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`yes\`, \`no\` or \`reset\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages the app script folders.
#
# Returns:
#   1 on failure, 0 otherwise
#####################################################
manage_tools() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks tools register [download|dialog] <scriptFolder>

    ( experimental feature )

    Install the script folder \`<scriptFolder>\` in 
    the installation directory under \`tools/<toolName>\`.

    >> Download Tool

    The interface of the download tool is as follows.
    
    # if \`run\` is executable
    \$ run <relativeFilePath> <outputFile>
    # otherwise, assuming \`run\` is a shell script
    \$ sh run <relativeFilePath> <outputFile>
    
    The arguments of the download tool are:
    - \`<relativeFilePath>\` is the file relative to the repository root
    - \`<outputFile>\` file to write the results to (may not exist yet)

    >> Dialog Tool

    The interface of the dialog tool is as follows.
    
    # if \`run\` is executable
    \$ run <title> <text> <options> <long-options>
    # otherwise, assuming \`run\` is a shell script
    \$ sh run <title> <text> <options> <long-options>

    The arguments of the dialog tool are:
    - \`<title>\` the title for the GUI dialog
    - \`<text>\` the text for the GUI dialog
    - \`<short-options>\` the button return values, slash-delimited, 
        e.g. \`Y/n/d\`.
        The default button is the first capital character found.
    - \`<long-options>\` the button texts in the GUI,
        e.g. \`Yes/no/disable\`

    The script needs to return one of the short-options on \`stdout\`.
    Non-zero exit code triggers the fallback of reading from \`stdin\`.

git hooks tools unregister [download|dialog]

    ( experimental feature )

    Uninstall the script folder in the installation 
    directory under \`tools/<toolName>\`.
"
        return
    fi

    TOOLS_OPERATION="$1"

    shift

    case "$TOOLS_OPERATION" in
    "register")
        tools_register "$@"
        ;;
    "unregister")
        tools_unregister "$@"
        ;;
    *)
        manage_tools "help"
        echo "! Invalid tools option: \`$TOOLS_OPERATION\`" >&2
        exit 1
        ;;
    esac
}

#####################################################
# Installs a script folder of a tool.
#
# Returns:
#   1 on failure, 0 otherwise
#####################################################
tools_register() {
    if [ "$1" = "download" ] || [ "$1" = "dialog" ]; then
        SCRIPT_FOLDER="$2"

        if [ -d "$SCRIPT_FOLDER" ]; then
            SCRIPT_FOLDER=$(cd "$SCRIPT_FOLDER" && pwd)

            if [ ! -f "$SCRIPT_FOLDER/run" ]; then
                echo "! File \`run\` does not exist in \`$SCRIPT_FOLDER\`" >&2
                exit 1
            fi

            if ! tools_unregister "$1" --quiet; then
                echo "! Unregister failed!" >&2
                exit 1
            fi

            TARGET_FOLDER="$INSTALL_DIR/tools/$1"

            mkdir -p "$TARGET_FOLDER" >/dev/null 2>&1 # Install new
            if ! cp -r "$SCRIPT_FOLDER"/* "$TARGET_FOLDER"/; then
                echo "! Registration failed" >&2
                exit 1
            fi
            echo "Registered \`$SCRIPT_FOLDER\` as \`$1\` tool"
        else
            echo "! The \`$SCRIPT_FOLDER\` directory does not exist!" >&2
            exit 1
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`download\` or  \`dialog\`)" >&2
        exit 1
    fi
}

#####################################################
# Uninstalls a script folder of a tool.
#
# Returns:
#   1 on failure, 0 otherwise
#####################################################
tools_unregister() {
    [ "$2" = "--quiet" ] && QUIET="Y"

    if [ "$1" = "download" ] || [ "$1" = "dialog" ]; then
        if [ -d "$INSTALL_DIR/tools/$1" ]; then
            rm -r "$INSTALL_DIR/tools/$1"
            [ -n "$QUIET" ] || echo "Uninstalled the \`$1\` tool"
        else
            [ -n "$QUIET" ] || echo "! The \`$1\` tool is not installed" >&2
        fi
    else
        [ -n "$QUIET" ] || echo "! Invalid tool: \`$1\` (use \`download\` or \`dialog\`)" >&2
        exit 1
    fi
}

#####################################################
# Prints the version number of this script,
#   that would match the latest installed version
#   of Githooks in most cases.
#####################################################
print_current_version_number() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks version

    Prints the version number of the \`git hooks\` helper and exits.
"
        return
    fi

    CURRENT_VERSION=$(grep -E "^# Version: .*" "$0" | head -1 | sed -E "s/^# Version: //")

    print_help_header

    echo
    echo "Version: $CURRENT_VERSION"
    echo
}

#####################################################
# Dispatches the command to the
#   appropriate helper function to process it.
#
# Returns:
#   1 if an unknown command was given,
#   the exit code of the command otherwise
#####################################################
choose_command() {
    CMD="$1"
    [ -n "$CMD" ] && shift

    case "$CMD" in
    "disable")
        disable_hook "$@"
        ;;
    "enable")
        enable_hook "$@"
        ;;
    "accept")
        accept_changes "$@"
        ;;
    "trust")
        manage_trusted_repo "$@"
        ;;
    "list")
        list_hooks "$@"
        ;;
    "shared")
        manage_shared_hook_repos "$@"
        ;;
    "pull")
        update_shared_hook_repos "$@"
        ;;
    "install")
        run_ondemand_installation "$@"
        ;;
    "uninstall")
        run_ondemand_uninstallation "$@"
        ;;
    "update")
        run_update_check "$@"
        ;;
    "readme")
        manage_readme_file "$@"
        ;;
    "ignore")
        manage_ignore_files "$@"
        ;;
    "config")
        manage_configuration "$@"
        ;;
    "tools")
        manage_tools "$@"
        ;;
    "version")
        print_current_version_number "$@"
        ;;
    "help")
        print_help
        ;;
    *)
        print_help
        [ -n "$CMD" ] && echo "! Unknown command: $CMD" >&2
        exit 1
        ;;
    esac
}

set_main_variables
# Choose and execute the command
choose_command "$@"
'

# A copy of the .githooks/README.md file's contents
# shellcheck disable=SC2016
INCLUDED_README_CONTENT='# Githooks

This project uses [Githooks](https://github.com/rycus86/githooks), that allows running [Git hooks](https://git-scm.com/docs/githooks) checked into this repository. This folder contains hooks that should be executed by everyone who interacts with this source repository. For a documentation on how this works and how to get it [installed](https://github.com/rycus86/githooks#installation), check the project [README](https://github.com/rycus86/githooks/blob/master/README.md) in the [rycus86/githooks](https://github.com/rycus86/githooks) GitHub repository.

## Brief summary

The [directories or files](https://github.com/rycus86/githooks#layout-and-options) in this folder tell Git to execute certain scripts on various [trigger events](https://github.com/rycus86/githooks#supported-hooks), before or after a commit, on every checkout, before a push for example - assuming [Githooks](https://github.com/rycus86/githooks) is already [installed](https://github.com/rycus86/githooks#installation) and [enabled](https://github.com/rycus86/githooks#opt-in-hooks) for the repository. The directory or file names refer to these events, like `pre-commit`, `post-commit`, `post-checkout`, `pre-push`, etc. If they are folders, each file inside them is treated as a hook script (unless [ignored](https://github.com/rycus86/githooks#ignoring-files)), and will be executed when Git runs the hooks as part of the command issued by the user. [Githooks](https://github.com/rycus86/githooks) comes with a [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool, that allows you to manage its configuration and state with a `git hooks <cmd>` command. See the [documentation](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) or run `git hooks help` for more information and available options.

### Is this safe?

[Githooks](https://github.com/rycus86/githooks) uses an [opt-in model](https://github.com/rycus86/githooks#opt-in-hooks), where it will ask for confirmation whether new or changed scripts should be run or not (or disabled).

### How do I add a new hook script?

Either create a file with the [Git hook](https://github.com/rycus86/githooks#supported-hooks) name, or a directory (recommended) inside the `.githooks` folder, and place files with the individual steps that should be executed for that event inside. If the file is executable, it will be invoked directly, otherwise it is assumed to be a Shell script - unless this file matches one of the [ignore patterns](https://github.com/rycus86/githooks#ignoring-files) in the `.githooks` area.

### How can I see what hooks are active?

You can look at the `.githooks` folder to see the local hooks in the repository, though if you have shared hook repositories defined, those will live under the `~/.githooks/shared` folder. The [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool can list out all of them for you with `git hooks list`, and you can use it to accept, enable or disable new, changed or existing hooks.

## More information

You can find more information about how this all works in the [README](https://github.com/rycus86/githooks/blob/master/README.md) of the [Githooks](https://github.com/rycus86/githooks) project repository.

If you find it useful, please show your support by starring the project in GitHub!'

############################################################
# Execute the full installation process.
#
# Returns:
#   0 when successfully finished, 1 if failed
############################################################
execute_installation() {
    # Global IFS for loops
    IFS_NEWLINE="
"
    parse_command_line_arguments "$@"

    load_install_dir

    if is_non_interactive; then
        disable_tty_input
    fi

    # Find the directory to install to
    if is_single_repo_install; then
        ensure_running_in_git_repo || return 1
        mark_as_single_install_repo
    else
        prepare_target_template_directory || return 1
    fi

    # Install the hook templates if needed
    if ! is_single_repo_install; then
        setup_hook_templates || return 1
        echo # For visual separation
    fi

    # Install the command line helper tool
    install_command_line_tool
    echo # For visual separation

    # Automatic updates
    if ! is_update_only && setup_automatic_update_checks; then
        echo # For visual separation
    fi

    if ! should_skip_install_into_existing_repositories; then
        if is_single_repo_install; then
            REPO_GIT_DIR=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd)
            install_hooks_into_repo "$REPO_GIT_DIR" || return 1
        else
            if ! is_update_only; then
                install_into_existing_repositories
            fi
            install_into_registered_repositories
        fi
    fi

    echo # For visual separation

    # Set up shared hook repositories if needed
    if ! is_update_only && ! is_non_interactive && ! is_single_repo_install; then
        setup_shared_hook_repositories
        echo # For visual separation
    fi
}

############################################################
# Sets the install directory.
#
# Returns:
#   1 when failed to configure the install directory,
#   0 otherwise
############################################################
load_install_dir() {
    # First check if we already have
    # an install directory set (from --prefix)
    if [ -z "$INSTALL_DIR" ]; then
        # load from config
        INSTALL_DIR=$(git config --global githooks.installDir)

        if [ -z "$INSTALL_DIR" ]; then
            # if still empty, then set to default
            INSTALL_DIR=~/".githooks"
        elif [ ! -d "$INSTALL_DIR" ]; then
            echo "! Configured install directory ${INSTALL_DIR} does not exist" >&2
            INSTALL_DIR=~/".githooks"
        fi
    fi

    if is_dry_run; then
        return 0
    fi

    if ! git config --global githooks.installDir "$INSTALL_DIR"; then
        echo "! Could not set \`githooks.installDir\`"
        return 1
    fi

    return 0
}

############################################################
# Set up variables based on command line arguments.
#
# Sets ${DRY_RUN} for --dry-run
# Sets ${NON_INTERACTIVE} for --non-interactive
# Sets ${SINGLE_REPO_INSTALL} for --single
# Sets ${SKIP_INSTALL_INTO_EXISTING} for --skip-install-into-existing
# Sets ${INSTALL_DIR} for --prefix
# Sets ${TARGET_TEMPLATE_DIR} for --template-dir
#
# Returns: None
############################################################
parse_command_line_arguments() {
    TARGET_TEMPLATE_DIR=""
    for p in "$@"; do
        if [ "$p" = "--dry-run" ]; then
            DRY_RUN="yes"
        elif [ "$p" = "--non-interactive" ]; then
            NON_INTERACTIVE="yes"
        elif [ "$p" = "--single" ]; then
            SINGLE_REPO_INSTALL="yes"
        elif [ "$p" = "--skip-install-into-existing" ]; then
            SKIP_INSTALL_INTO_EXISTING="yes"

        elif [ "$prev_p" = "--prefix" ] && (echo "$p" | grep -qvE '^\-\-.*'); then
            # Allow user to pass prefered install prefix
            INSTALL_DIR="$p"

            # Try to see if the path is given with a tilde
            TILDE_REPLACED=$(echo "$INSTALL_DIR" | awk 'gsub("~", "'"$HOME"'", $0)')
            if [ -n "$TILDE_REPLACED" ]; then
                INSTALL_DIR="$TILDE_REPLACED"
            fi

            INSTALL_DIR="$INSTALL_DIR/.githooks"

        elif [ "$p" = "--template-dir" ]; then
            : # nothing to do here
        elif [ "$prev_p" = "--template-dir" ] && (echo "$p" | grep -qvE '^\-\-.*'); then
            # Allow user to pass prefered template dir
            TARGET_TEMPLATE_DIR="$p"
        elif [ "$p" = "--only-server-hooks" ]; then
            INSTALL_ONLY_SERVER_HOOKS="yes"
        elif [ "$p" = "--use-core-hookspath" ]; then
            USE_CORE_HOOKSPATH="yes"
            # No point in installing into existing when using core.hooksPath
            SKIP_INSTALL_INTO_EXISTING="yes"
        else
            echo "! Unknown argument \`$p\`" >&2
        fi
        prev_p="$p"
    done

    # Using core.hooksPath implies it applies to all repo's
    if [ "$SINGLE_REPO_INSTALL" = "yes" ] && [ "$USE_CORE_HOOKSPATH" = "yes" ]; then
        echo "! Cannot use --single and --use-core-hookspath together" >&2
        exit 1
    fi
}

############################################################
# Check if the install script is
#   running in 'dry-run' mode.
#
# Returns:
#   0 in dry-run mode, 1 otherwise
############################################################
is_dry_run() {
    if [ "$DRY_RUN" = "yes" ]; then
        return 0
    else
        return 1
    fi
}

############################################################
# Check if the install script is
#   running in non-interactive mode.
#
# Returns:
#   0 in non-interactive mode, 1 otherwise
############################################################
is_non_interactive() {
    if [ "$NON_INTERACTIVE" = "yes" ]; then
        return 0
    else
        return 1
    fi
}

############################################################
# Check if we should skip installing hooks
#   into existing repositories.
#
# Returns:
#   0 if we should skip, 1 otherwise
############################################################
should_skip_install_into_existing_repositories() {
    if [ "$SKIP_INSTALL_INTO_EXISTING" = "yes" ]; then
        return 0
    else
        return 1
    fi
}

############################################################
# Check if the install script is
#   running in for a single repository without templates.
#
# Returns:
#   0 in single repository install mode, 1 otherwise
############################################################
is_single_repo_install() {
    if [ "$SINGLE_REPO_INSTALL" = "yes" ]; then
        return 0
    else
        return 1
    fi
}

############################################################
# Check if the install script is only an update executed by
#   a running hook.
#
# Returns:
#   0 if its an update, 1 otherwise
############################################################
is_update_only() {
    [ "$DO_UPDATE_ONLY" = "yes" ] || return 1
}

############################################################
# Disable user input by redirecting /dev/null
#   to the standard input of the install script.
#
# Returns:
#   None
############################################################
disable_tty_input() {
    exec </dev/null
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
# Checks whether the current working directory
#   is a Git repository or not.
#
# Returns:
#   1 if failed, 0 otherwise
############################################################
ensure_running_in_git_repo() {
    if ! is_git_repo "$(pwd)"; then
        echo "! The current directory is not a Git repository" >&2
        return 1
    fi
}

############################################################
# Marks the repository in the current working directory
#   as a single install project for future Githooks
#   install or update runs.
#
# Sets the 'githooks.single.install' configuration.
#
# Returns:
#   None
############################################################
mark_as_single_install_repo() {
    git config --local githooks.single.install yes
    git config --local --unset githooks.autoupdate.registered
}

############################################################
# Prepare the target template directory variable,
#   and make sure it points to a directory when set.
#
# Sets the ${TARGET_TEMPLATE_DIR} variable.
#
# Returns:
#   1 if failed, 0 otherwise
############################################################
prepare_target_template_directory() {
    if [ -z "$TARGET_TEMPLATE_DIR" ]; then
        find_git_hook_templates
    fi

    if [ ! -d "$TARGET_TEMPLATE_DIR" ]; then
        echo "Git hook templates directory not found" >&2
        return 1
    fi

    if [ "$USE_CORE_HOOKSPATH" = "yes" ]; then
        set_githooks_directory "$TARGET_TEMPLATE_DIR"
    fi
}

############################################################
# Try to find the directory where the Git
#   hook templates are currently.
#
# Sets ${TARGET_TEMPLATE_DIR} if found.
#
# Returns:
#   None
############################################################
find_git_hook_templates() {
    # 1. from environment variables
    mark_directory_as_target "$GIT_TEMPLATE_DIR" "hooks"
    if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi

    # 2. from git config
    if [ "$USE_CORE_HOOKSPATH" = "yes" ]; then
        mark_directory_as_target "$(git config --global core.hooksPath)"
    else
        mark_directory_as_target "$(git config --global init.templateDir)" "hooks"
    fi
    if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi

    # 3. from the default location
    mark_directory_as_target "/usr/share/git-core/templates/hooks"
    if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi

    # 4. Setup new folder if running interactively and no folder is found by now
    if is_non_interactive; then
        setup_new_templates_folder
        return # we are finished either way here
    fi

    # 5. try to search for it on disk
    printf 'Could not find the Git hook template directory. '
    printf 'Do you want to search for it? [y/N] '
    read -r DO_SEARCH </dev/tty

    if [ "${DO_SEARCH}" = "y" ] || [ "${DO_SEARCH}" = "Y" ]; then
        search_for_templates_dir

        if [ "$TARGET_TEMPLATE_DIR" != "" ]; then
            printf 'Do you want to set this up as the Git template directory for future use? [y/N] '
            read -r MARK_AS_TEMPLATES </dev/tty

            if [ "$MARK_AS_TEMPLATES" = "y" ] || [ "$MARK_AS_TEMPLATES" = "Y" ]; then
                TEMPLATE_DIR=$(dirname "$TARGET_TEMPLATE_DIR")

                if ! set_githooks_directory "$TEMPLATE_DIR"; then
                    echo "! Failed to set it up as Git template directory" >&2
                fi
            fi

            return
        fi
    fi

    # 6. set up as new
    printf "Do you want to set up a new Git templates folder? [y/N] "
    read -r SETUP_NEW_FOLDER </dev/tty

    if [ "${SETUP_NEW_FOLDER}" = "y" ] || [ "${SETUP_NEW_FOLDER}" = "Y" ]; then
        setup_new_templates_folder
        if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi
    fi
}

############################################################
# Sets the ${TARGET_TEMPLATE_DIR} variable if the
#   first parameter is a writable directory.
#
# Returns:
#   None
############################################################
mark_directory_as_target() {
    TARGET="$1"
    if [ "$TARGET" = "" ]; then
        return
    fi

    if [ "$2" != "" ]; then
        TARGET="${TARGET}/$2"
    fi

    if [ -w "$TARGET" ]; then
        TARGET_TEMPLATE_DIR="$TARGET"
        return
    fi

    # Try to see if the path is given with a tilde
    TILDE_REPLACED=$(echo "$TARGET" | awk 'gsub("~", "'"$HOME"'", $0)')
    if [ -n "$TILDE_REPLACED" ] && [ -w "$TILDE_REPLACED" ]; then
        TARGET_TEMPLATE_DIR="$TILDE_REPLACED"
        return
    fi
}

############################################################
# Search for the template directory on the file system.
#
# Sets ${TARGET_TEMPLATE_DIR} if found.
#
# Returns:
#   None
############################################################
search_for_templates_dir() {
    if [ -d "/usr" ]; then
        echo "Searching for potential locations in /usr ..."
        search_pre_commit_sample_file "/usr"

        if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi
    fi

    if is_non_interactive; then
        return
    fi

    printf 'Git hook template directory not found in /usr. '
    printf 'Do you want to keep searching? [y/N] '
    read -r DO_SEARCH </dev/tty

    if [ "${DO_SEARCH}" = "y" ] || [ "${DO_SEARCH}" = "Y" ]; then
        echo "Searching for potential locations everywhere ..."
        search_pre_commit_sample_file "/"
    fi

    if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi
}

############################################################
# Heuristics: Try to look for a default hook sample file
#
# Sets ${TARGET_TEMPLATE_DIR} if found.
#
# Returns:
#   None
############################################################
search_pre_commit_sample_file() {
    START_DIR="$1"

    IFS="$IFS_NEWLINE"
    # shellcheck disable=SC2044
    for HIT in $(find "$START_DIR" -path "*templates/hooks/pre-commit.sample" 2>/dev/null); do
        unset IFS

        HIT=$(dirname "$HIT")

        if [ ! -w "$HIT" ]; then
            echo "Skipping non-writable directory: $HIT"
            continue
        fi

        printf -- "- Is it %s ? [y/N] " "$HIT"
        read -r ACCEPT </dev/tty

        if [ "$ACCEPT" = "y" ] || [ "$ACCEPT" = "Y" ]; then
            TARGET_TEMPLATE_DIR="$HIT"
            return
        fi
        IFS="$IFS_NEWLINE"
    done
    unset IFS
}

############################################################
# Setup a new Git templates folder.
#
# Returns:
#   None
############################################################
setup_new_templates_folder() {
    DEFAULT_TARGET="$INSTALL_DIR/templates"

    if is_non_interactive; then
        USER_TEMPLATES="$DEFAULT_TARGET"
    else
        printf "Enter the target folder: [%s] " "$DEFAULT_TARGET"
        read -r USER_TEMPLATES </dev/tty
    fi

    if [ "$USER_TEMPLATES" = "" ]; then
        USER_TEMPLATES="$DEFAULT_TARGET"
    fi

    TILDE_REPLACED=$(echo "$USER_TEMPLATES" | awk 'gsub("~", "'"$HOME"'", $0)')
    if [ -z "$TILDE_REPLACED" ]; then
        TILDE_REPLACED="$USER_TEMPLATES"
    fi

    if ! is_dry_run; then
        if mkdir -p "${TILDE_REPLACED}/hooks"; then
            # Let this one go with or without a tilde
            set_githooks_directory "$USER_TEMPLATES"
        else
            echo "! Failed to set up the new Git templates folder" >&2
            return
        fi
    fi

    TARGET_TEMPLATE_DIR="${TILDE_REPLACED}/hooks"
}

############################################################
# Install the new Git hook templates into the
#   ${TARGET_TEMPLATE_DIR} directory that we
#   have found previously.
#
# Returns:
#   0 on success, 1 on failure
############################################################
setup_hook_templates() {
    if is_dry_run; then
        echo "[Dry run] Would install Git hook templates into $TARGET_TEMPLATE_DIR"
        return 0
    fi

    if [ "$(git config --global githooks.maintainOnlyServerHooks)" = "Y" ]; then
        INSTALL_ONLY_SERVER_HOOKS="yes"
    fi

    if [ "$INSTALL_ONLY_SERVER_HOOKS" = "yes" ]; then
        HOOK_NAMES="$MANAGED_SERVER_HOOK_NAMES"
    else
        HOOK_NAMES="$MANAGED_HOOK_NAMES"
    fi

    for HOOK in $HOOK_NAMES; do
        HOOK_TEMPLATE="${TARGET_TEMPLATE_DIR}/${HOOK}"

        if [ -x "$HOOK_TEMPLATE" ]; then
            grep 'https://github.com/rycus86/githooks' "${HOOK_TEMPLATE}" >/dev/null 2>&1

            # shellcheck disable=SC2181
            if [ $? -ne 0 ]; then
                echo "Saving existing Git hook: $HOOK"
                mv "$HOOK_TEMPLATE" "${HOOK_TEMPLATE}.replaced.githook"
            fi
        fi

        if echo "$BASE_TEMPLATE_CONTENT" >"$HOOK_TEMPLATE" && chmod +x "$HOOK_TEMPLATE"; then
            echo "Git hook template ready: $HOOK_TEMPLATE"
        else
            echo "! Failed to setup the $HOOK template at $HOOK_TEMPLATE" >&2
            return 1
        fi
    done

    if [ "$INSTALL_ONLY_SERVER_HOOKS" = "yes" ]; then
        git config --global githooks.maintainOnlyServerHooks "Y"
    fi

    return 0
}

############################################################
# Installs the command line helper tool at
#   $INSTALL_DIR/bin/githooks and adds a Git alias for it.
#
# Returns:
#   None
############################################################
install_command_line_tool() {
    mkdir -p "$INSTALL_DIR/bin" &&
        echo "$CLI_TOOL_CONTENT" >"$INSTALL_DIR/bin/githooks" &&
        chmod +x "$INSTALL_DIR/bin/githooks" &&
        git config --global alias.hooks "!$INSTALL_DIR/bin/githooks" &&
        echo "The command line helper tool is installed at ${INSTALL_DIR}/bin/githooks, and it is now available as 'git hooks <cmd>'" &&
        return

    echo "! Failed to setup the command line helper automatically. If you'd like to do it manually, install the 'cli.sh' file from the repository into a folder on your PATH environment variable, and make it executable." >&2
    echo "  Direct link to the script: https://raw.githubusercontent.com/rycus86/githooks/master/cli.sh" >&2
}

############################################################
# Prompt whether to enable automatic update checks or not.
#   This is skipped if it is already enabled.
#   If it is currently disabled, it asks if you
#   want it enabled.
#
# Returns:
#   1 when already enabled, 0 otherwise
############################################################
setup_automatic_update_checks() {
    if CURRENT_SETTING=$(git config --get githooks.autoupdate.enabled); then
        if [ "$CURRENT_SETTING" = "Y" ]; then
            # OK, it's already enabled
            return 1
        else
            echo "Automatic update checks are currently disabled."

            if is_non_interactive; then
                return 1
            else
                printf "Would you like to re-enable them, done once a day after a commit? [Y/n] "
            fi
        fi

    elif is_non_interactive; then
        DO_AUTO_UPDATES="Y"

    else
        printf "Would you like to enable automatic update checks, done once a day after a commit? [Y/n] "

    fi

    if ! is_non_interactive; then
        read -r DO_AUTO_UPDATES </dev/tty
    fi

    if [ -z "$DO_AUTO_UPDATES" ] || [ "$DO_AUTO_UPDATES" = "y" ] || [ "$DO_AUTO_UPDATES" = "Y" ]; then
        if ! is_single_repo_install; then
            GLOBAL_CONFIG="--global"
        fi

        if is_dry_run; then
            echo "[Dry run] Automatic update checks would have been enabled"
        elif git config ${GLOBAL_CONFIG} githooks.autoupdate.enabled Y; then
            echo "Automatic update checks are now enabled"
        else
            echo "! Failed to enable automatic update checks" >&2
        fi
    else
        echo "If you change your mind in the future, you can enable it by running:"
        echo "  \$ git hooks update enable"
    fi
}

############################################################
# Find existing repositories from a start directory `$1`.
#   Sets the variable `$EXISTING_REPOSITORY_LIST`
#
# Returns:
#   0 on success, 1 on failure
############################################################
find_existing_git_dirs() {

    REPOSITORY_LIST=$(
        find "$1" \( -type d -and -name .git \) -or \
            \( -type f -and -name HEAD -and -not -path "*/.git/*" \) 2>/dev/null
    )

    # List if existing Git repositories
    EXISTING_REPOSITORY_LIST=""

    IFS="$IFS_NEWLINE"
    for EXISTING in $REPOSITORY_LIST; do
        unset IFS

        if [ -f "$EXISTING" ]; then
            # Strip HEAD file
            EXISTING=$(dirname "$EXISTING")
        fi

        # Try to go to the root git dir (works in bare and non-bare repositories)
        # to neglect false positives from the find above
        # e.g. spourious HEAD file or .git dir which does not mark a repository
        REPO_GIT_DIR=$(cd "$EXISTING" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd)

        if is_git_repo "$REPO_GIT_DIR" && ! echo "$EXISTING_REPOSITORY_LIST" | grep -q "$REPO_GIT_DIR"; then
            EXISTING_REPOSITORY_LIST="$REPO_GIT_DIR
$EXISTING_REPOSITORY_LIST"
        fi
    done

    # Sort the list if we can
    if sort --help >/dev/null 2>&1; then
        EXISTING_REPOSITORY_LIST=$(echo "$EXISTING_REPOSITORY_LIST" | sort)
    fi
}

############################################################
# Install the new Git hook templates into the
#   existing local repositories.
#
# Returns:
#   None
############################################################
install_into_existing_repositories() {
    PRE_START_DIR=$(git config --global --get githooks.previous.searchdir)
    # shellcheck disable=SC2181
    if [ $? -eq 0 ] && [ -n "$PRE_START_DIR" ]; then
        HAS_PRE_START_DIR="Y"
    else
        PRE_START_DIR="$HOME"
    fi

    if [ "$HAS_PRE_START_DIR" = "Y" ]; then
        QUESTION_PROMPT="[Y/n]"
    else
        QUESTION_PROMPT="[y/N]"
    fi

    if is_non_interactive; then
        echo "Installing the hooks into existing repositories under $PRE_START_DIR"
        START_DIR="$PRE_START_DIR"

    else
        printf 'Do you want to install the hooks into existing repositories? %s ' "$QUESTION_PROMPT"
        read -r DO_INSTALL </dev/tty

        if [ "$DO_INSTALL" != "y" ] && [ "$DO_INSTALL" != "Y" ]; then
            if [ "$HAS_PRE_START_DIR" != "Y" ] || [ -n "$DO_INSTALL" ]; then
                return
            fi
        fi

        printf 'Where do you want to start the search? [%s] ' "$PRE_START_DIR"
        read -r START_DIR </dev/tty
    fi

    if [ "$START_DIR" = "" ]; then
        START_DIR="$PRE_START_DIR"
    fi

    RAW_START_DIR="$START_DIR"
    TILDE_REPLACED=$(echo "$START_DIR" | awk 'gsub("~", "'"$HOME"'", $0)')
    if [ -n "$TILDE_REPLACED" ]; then
        START_DIR="$TILDE_REPLACED"
    fi

    if [ ! -d "$START_DIR" ]; then
        echo "! '$START_DIR' is not a directory" >&2
        echo "  Existing repositories won't get the Githooks hooks." >&2
        return
    fi

    git config --global githooks.previous.searchdir "$RAW_START_DIR"

    find_existing_git_dirs "$START_DIR"

    # Loop over all existing git dirs
    IFS="$IFS_NEWLINE"
    for EXISTING in $EXISTING_REPOSITORY_LIST; do
        unset IFS

        install_hooks_into_repo "$EXISTING" &&
            register_repo_for_autoupdate "$EXISTING"

        IFS="$IFS_NEWLINE"
    done
    unset IFS

    return
}

############################################################
# Disable a locally installed LFS hook `$1` if detected.
#   By default, a detected lfs hook is disabled and
#   backed up.
#   Sets the variable `DELETE_DETECTED_LFS_HOOKS` for
#   later invocations.
#
# Returns:
#   0 on moved or deleted, 1 otherwise
############################################################
disable_lfs_hook_if_detected() {
    HOOK_FILE="$1"

    if [ -f "$HOOK_FILE" ] &&
        grep -qE "(git\s+lfs|git-lfs)" "$HOOK_FILE"; then

        # Load the global decision
        if [ -z "$DELETE_DETECTED_LFS_HOOKS" ]; then
            DELETE_DETECTED_LFS_HOOKS=$(git config --global githooks.deleteDetectedLFSHooks)
        fi

        if ! is_non_interactive && [ -z "$DELETE_DETECTED_LFS_HOOKS" ]; then
            echo "! There is an LFS commmand statement in \`$HOOK_FILE\`."
            echo "  Githooks will call LFS hooks internally and LFS should not be called twice."
            printf "  Do you want to delete this hook instead of beeing disabled/backed up? (No, yes, all, skip all) [N,y,a,s] "

            read -r DELETE_DETECTED_LFS_HOOKS </dev/tty

            # Store decision
            if echo "$DELETE_DETECTED_LFS_HOOKS" | grep -qwE "a|A|s|S"; then
                git config --global githooks.deleteDetectedLFSHooks "$DELETE_DETECTED_LFS_HOOKS"
            fi
        fi

        DELETE="N"
        if echo "$DELETE_DETECTED_LFS_HOOKS" | grep -qwE "a|A"; then
            DELETE="y"
        elif echo "$DELETE_DETECTED_LFS_HOOKS" | grep -qwE "y|Y|n|N"; then
            DELETE="$DELETE_DETECTED_LFS_HOOKS"
            unset DELETE_DETECTED_LFS_HOOKS
        fi

        if [ "$DELETE" = "y" ] || [ "$DELETE" = "Y" ]; then
            echo "LFS hook \`$HOOK_FILE\` deleted"
            rm -f "$HOOK_FILE" >/dev/null 2>&1
        else
            echo "LFS hook \`$HOOK_FILE\` disabled and moved to \`$HOOK_FILE.disabled.githooks\`"
            mv -f "$HOOK_FILE" "$HOOK_FILE.disabled.githooks" >/dev/null 2>&1
        fi
        return 0
    fi
    return 1
}

############################################################
# Install the new Git hook templates into
#   all repos registered for autoupdate.
#
# Returns: None
############################################################
install_into_registered_repositories() {

    LIST="$INSTALL_DIR/autoupdate/registered"
    if [ -f "$LIST" ]; then

        # Filter list according to
        # - non-existing repos
        # - already installed
        # - if marked as single install.

        # The list of repositories we still need to update if the user agrees.
        INSTALL_LIST=$(mktemp)
        # The new list of all registered repositories
        NEW_LIST=$(mktemp)

        IFS="$IFS_NEWLINE"
        while read -r INSTALLED_REPO; do
            unset IFS

            if [ "$(git -C "$INSTALLED_REPO" rev-parse --is-inside-git-dir)" = "false" ]; then
                # Not existing git dir -> skip.
                true

            elif (cd "$INSTALLED_REPO" && [ "$(git config --local githooks.single.install)" = "yes" ]); then
                # Found a registed repo which is now a single install:
                # For safety: Remove registered flag and skip.
                git -C "$INSTALLED_REPO" config --local --unset githooks.autoupdate.registered >/dev/null 2>&1

            elif echo "$EXISTING_REPOSITORY_LIST" | grep -q "$INSTALLED_REPO"; then
                # We already installed to this repository, don't install
                echo "$INSTALLED_REPO" >>"$NEW_LIST"

            else
                # Existing registed repository, install.
                echo "$INSTALLED_REPO" >>"$NEW_LIST"
                echo "$INSTALLED_REPO" >>"$INSTALL_LIST"
            fi

            IFS="$IFS_NEWLINE"
        done <"$LIST"

        # Move the new cleaned list into place
        mv -f "$NEW_LIST" "$LIST"

        if [ -s "$INSTALL_LIST" ]; then

            if is_non_interactive; then
                # Install into registered repositories by default
                true
            else
                echo "The following remaining registered repositories in \`$LIST\`"
                echo "contain a Githooks installation:"
                sed -E "s/^/ - /" <"$INSTALL_LIST"
                printf 'Do you want to install to all of them? [Yn] '

                read -r DO_INSTALL </dev/tty
                if [ "$DO_INSTALL" = "n" ] || [ "$DO_INSTALL" = "N" ]; then
                    rm -f "$INSTALL_LIST" >/dev/null 2>&1
                    return 0
                fi
            fi

            # Loop over all existing git dirs
            IFS="$IFS_NEWLINE"
            while read -r REPO_GIT_DIR; do
                unset IFS

                install_hooks_into_repo "$REPO_GIT_DIR"

                # no register_repo_for_autoupdate needed
                # since already in the list

                IFS="$IFS_NEWLINE"
            done <"$INSTALL_LIST"

        fi

        rm -f "$INSTALL_LIST" >/dev/null 2>&1
    fi
}

############################################################
# Install the new Git hook templates into an existing
#   local repository, given by the first parameter.
#
# Returns:
#   0 on success, 1 on failure
############################################################
install_hooks_into_repo() {
    TARGET="$1"

    IS_BARE=$(git -C "${TARGET}" rev-parse --is-bare-repository 2>/dev/null)

    if [ ! -w "${TARGET}/hooks" ]; then
        # Try to create the .git/hooks folder
        if ! mkdir "${TARGET}/hooks" 2>/dev/null; then
            echo "! Could not install into \`$TARGET\` because there is no write access."
            return 1
        fi
    fi

    INSTALLED="no"

    if [ "$IS_BARE" = "true" ]; then
        HOOK_NAMES="$MANAGED_SERVER_HOOK_NAMES"
    else
        HOOK_NAMES="$MANAGED_HOOK_NAMES"
    fi

    for HOOK_NAME in $HOOK_NAMES; do
        if is_dry_run; then
            INSTALLED="yes"
            continue
        fi

        TARGET_HOOK="${TARGET}/hooks/${HOOK_NAME}"

        if [ -f "$TARGET_HOOK" ]; then
            grep 'https://github.com/rycus86/githooks' "${TARGET_HOOK}" >/dev/null 2>&1

            # shellcheck disable=SC2181
            if [ $? -ne 0 ]; then
                # Save the existing Git hook so that we'll continue to execute it
                if ! disable_lfs_hook_if_detected "$TARGET_HOOK" &&
                    ! mv "$TARGET_HOOK" "${TARGET_HOOK}.replaced.githook"; then
                    HAD_FAILURE=Y
                    echo "! Failed to save the existing hook at $TARGET_HOOK" >&2
                    continue
                fi
            fi

            # Try to delete this hook first, because it could be currently running.
            # The file stays around till the last file descriptor is freed.
            rm -f "$TARGET_HOOK" >/dev/null 2>&1
        fi

        if echo "$BASE_TEMPLATE_CONTENT" >"$TARGET_HOOK" && chmod +x "$TARGET_HOOK"; then
            INSTALLED="yes"
        else
            HAD_FAILURE=Y
            echo "! Failed to install $TARGET_HOOK" >&2
        fi
    done

    # Offer to setup the intro README if running in interactive mode
    # Let's skip this in non-interactive mode or in a bare repository
    # to avoid polluting the repos with README files
    if is_non_interactive || [ "${IS_BARE}" = "true" ]; then
        true
    else
        # Getting the working tree (no external .git directories)
        # see https://stackoverflow.com/a/38852055/293195
        TARGET_ROOT=$(git -C "${TARGET}" rev-parse --show-toplevel 2>/dev/null)
        if [ -z "$TARGET_ROOT" ]; then
            TARGET_ROOT=$(cd "${TARGET}" && cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." && pwd)
        fi

        if [ -d "${TARGET_ROOT}" ] && is_git_repo "$TARGET_ROOT" &&
            [ ! -f "${TARGET_ROOT}/.githooks/README.md" ]; then
            if [ "$SETUP_INCLUDED_README" = "s" ] || [ "$SETUP_INCLUDED_README" = "S" ]; then
                true # OK, we already said we want to skip all

            elif [ "$SETUP_INCLUDED_README" = "a" ] || [ "$SETUP_INCLUDED_README" = "A" ]; then
                mkdir -p "${TARGET_ROOT}/.githooks" &&
                    echo "$INCLUDED_README_CONTENT" >"${TARGET_ROOT}/.githooks/README.md"

            else
                if [ ! -d "${TARGET_ROOT}/.githooks" ]; then
                    echo "Looks like you don't have a .githooks folder in the ${TARGET_ROOT} repository yet."
                    printf "  Would you like to create one with a README containing a brief overview of Githooks? (Yes, no, all, skip all) [Y/n/a/s] "
                else
                    echo "Looks like you don't have a README.md in the ${TARGET_ROOT}/.githooks folder yet."
                    echo "  A README file might help contributors and other team members learn about what is this for."
                    printf "  Would you like to add one now with a brief overview of Githooks? (Yes, no, all, skip all) [Y/n/a/s] "
                fi

                read -r SETUP_INCLUDED_README </dev/tty

                if [ -z "$SETUP_INCLUDED_README" ] ||
                    [ "$SETUP_INCLUDED_README" = "y" ] || [ "$SETUP_INCLUDED_README" = "Y" ] ||
                    [ "$SETUP_INCLUDED_README" = "a" ] || [ "$SETUP_INCLUDED_README" = "A" ]; then

                    mkdir -p "${TARGET_ROOT}/.githooks" &&
                        echo "$INCLUDED_README_CONTENT" >"${TARGET_ROOT}/.githooks/README.md"
                fi
            fi
        fi
    fi

    if [ "$INSTALLED" = "yes" ]; then
        if is_dry_run; then
            echo "[Dry run] Hooks would have been installed into $TARGET"
        else
            echo "Hooks installed into $TARGET"
        fi
    fi

    if [ "$HAD_FAILURE" = "Y" ]; then
        return 1
    else
        return 0
    fi
}

############################################################
# Adds the repository to the list `autoupdate.registered`
#  for potential future autoupdates.
#
# Returns: 0
############################################################
register_repo_for_autoupdate() {
    CURRENT_REPO="$(cd "$1" && pwd)"
    LIST="$INSTALL_DIR/autoupdate/registered"

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

    # Mark the repo as registered.
    (git -C "$CURRENT_REPO" config --local githooks.autoupdate.registered "yes")

    return 0
}

############################################################
# Optionally setup shared hook repositories locally
#   with their related Git config variables.
#
# Returns:
#   None
############################################################
setup_shared_hook_repositories() {
    if [ -n "$(git config --global --get githooks.shared)" ]; then
        printf "Looks like you already have shared hook repositories setup, do you want to change them now? [y/N] "
    else
        echo "You can set up shared hook repositories to avoid duplicating common hooks across repositories you work on. See information on what are these in the project's documentation at https://github.com/rycus86/githooks#shared-hook-repositories"
        echo "Note: you can also have a .githooks/.shared file listing the repositories where you keep the shared hook files"
        printf "Would you like to set up shared hook repos now? [y/N] "
    fi

    read -r DO_SETUP </dev/tty
    if [ "$DO_SETUP" != "y" ] && [ "$DO_SETUP" != "Y" ]; then return; fi

    echo "OK, let's input them one-by-one and leave the input empty to stop."

    SHARED_REPOS_LIST=""
    while true; do
        printf "Enter the clone URL of a shared repository: "
        read -r SHARED_REPO </dev/tty
        if [ -z "$SHARED_REPO" ]; then break; fi

        if [ -n "$SHARED_REPOS_LIST" ]; then
            SHARED_REPOS_LIST="${SHARED_REPOS_LIST},${SHARED_REPO}"
        else
            SHARED_REPOS_LIST="$SHARED_REPO"
        fi
    done

    if [ -z "$SHARED_REPOS_LIST" ] && git config --global --unset githooks.shared; then
        echo "Shared hook repositories are now unset. If you want to set them up again in the future, run this script again, or change the 'githooks.shared' Git config variable manually."
        echo "Note: shared hook repos listed in the .githooks/.shared file will still be executed"
    elif git config --global githooks.shared "$SHARED_REPOS_LIST"; then
        # Trigger the shared hook repository checkout manually
        echo "$BASE_TEMPLATE_CONTENT" >".githooks.shared.trigger" &&
            chmod +x ".githooks.shared.trigger" &&
            ./.githooks.shared.trigger
        rm -f .githooks.shared.trigger

        echo "Shared hook repositories have been set up. You can change them any time by running this script again, or manually by changing the 'githooks.shared' Git config variable."
        echo "Note: you can also list the shared hook repos per project within the .githooks/.shared file"
    else
        echo "! Failed to set up the shared hook repositories" >&2
    fi
}

############################################################
# Sets the githooks templatedir or hookspath
#   config variable
#
# Parameters:
#   1: path for templateDir or hooksPath
#
# Returns:
#   None
############################################################
set_githooks_directory() {
    if [ "$USE_CORE_HOOKSPATH" = "yes" ]; then
        git config --global githooks.useCoreHooksPath yes
        git config --global githooks.pathForUseCoreHooksPath "$1"
        git config --global core.hooksPath "$1"
    else
        git config --global githooks.useCoreHooksPath no
        git config --global init.templateDir "$1"

        CURRENT_CORE_HOOKS_PATH=$(git config --global core.hooksPath)
        if [ -n "$CURRENT_CORE_HOOKS_PATH" ]; then
            echo "! The \`core.hooksPath\` setting is set to $CURRENT_CORE_HOOKS_PATH currently" >&2
            echo "  This could mean that Githooks hooks will be ignored" >&2
            echo "  Either unset \`core.hooksPath\` or run the Githooks installation with the --use-core-hookspath parameter" >&2
        fi
    fi
}

############################################################
# Prints a thank you message and some more info
#   when the script is finished.
#
# Returns:
#   None
############################################################
thank_you() {
    echo "All done! Enjoy!"
    echo
    echo "Please support the project by starring the project at https://github.com/rycus86/githooks, and report bugs or missing features or improvements as issues. Thanks!"
}

# Start the installation process
execute_installation "$@" || exit 1
thank_you
