#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.
#
# Version: 1907.020017-f69431

# The main update url.
MAIN_DOWNLOAD_URL="https://raw.githubusercontent.com/rycus86/githooks/master"
# If the update url needs credentials, use `git credential fill` to
# get this information.
DOWNLOAD_USE_CREDENTIALS="N"

#####################################################
# Execute the current hook,
#   that in turn executes the hooks in the repo.
#
# Returns:
#   0 when successfully finished, 1 otherwise
#####################################################
process_git_hook() {
    are_githooks_disabled && return 0
    set_main_variables
    export_staged_files
    check_for_updates_if_needed
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
# Set up the main variables that
#   we will throughout the hook.
#
# Sets the ${HOOK_NAME} variable
# Sets the ${HOOK_FOLDER} variable
# Resets the ${ACCEPT_CHANGES} variable
# Sets the ${CURRENT_GIT_DIR} variable
#
# Returns:
#   None
#####################################################
set_main_variables() {
    HOOK_NAME=$(basename "$0")
    HOOK_FOLDER=$(dirname "$0")
    ACCEPT_CHANGES=

    CURRENT_GIT_DIR=$(git rev-parse --git-common-dir)
    if [ "${CURRENT_GIT_DIR}" = "--git-common-dir" ]; then
        CURRENT_GIT_DIR=".git" # reset to a sensible default
    fi
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
            echo "! This repository wants you to trust all current and future hooks without prompting"
            printf "  Do you want to allow running every current and future hooks? [y/N] "
            read -r TRUST_ALL_HOOKS </dev/tty

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

        echo "? $MESSAGE: $HOOK_PATH"

        if [ "$ACCEPT_CHANGES" = "a" ] || [ "$ACCEPT_CHANGES" = "A" ]; then
            echo "  Already accepted"
        else
            printf "  Do you you accept the changes? (Yes, all, no, disable) [Y/a/n/d] "
            read -r ACCEPT_CHANGES </dev/tty

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

    update_shared_hooks_if_appropriate
    execute_shared_hooks "$@" || return 1
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
    if [ "$HOOK_NAME" = "post-merge" ] || [ "$HOOK_NAME" = ".githooks.shared.trigger" ]; then
        # split on comma and newline
        IFS=",
        "

        for SHARED_REPO in $SHARED_REPOS_LIST; do
            mkdir -p ~/.githooks/shared

            NORMALIZED_NAME=$(echo "$SHARED_REPO" |
                sed -E "s#.*[:/](.+/.+)\\.git#\\1#" |
                sed -E "s/[^a-zA-Z0-9]/_/g")

            if [ -d ~/.githooks/shared/"$NORMALIZED_NAME"/.git ]; then
                echo "* Updating shared hooks from: $SHARED_REPO"
                PULL_OUTPUT=$(cd ~/.githooks/shared/"$NORMALIZED_NAME" && git pull 2>&1)
                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Update failed, git pull output:"
                    echo "$PULL_OUTPUT"
                fi
            else
                echo "* Retrieving shared hooks from: $SHARED_REPO"
                CLONE_OUTPUT=$(cd ~/.githooks/shared && git clone "$SHARED_REPO" "$NORMALIZED_NAME" 2>&1)
                # shellcheck disable=SC2181
                if [ $? -ne 0 ]; then
                    echo "! Clone failed, git clone output:"
                    echo "$CLONE_OUTPUT"
                fi
            fi
        done

        unset IFS
    fi
}

#####################################################
# Execute the shared hooks in the
#   ~/.githooks/shared directory.
#
# Returns:
#   1 in case a hook fails, 0 otherwise
#####################################################
execute_shared_hooks() {
    for SHARED_ROOT in ~/.githooks/shared/*; do
        REMOTE_URL=$(cd "$SHARED_ROOT" && git config --get remote.origin.url)
        ACTIVE_REPO=$(echo "$SHARED_REPOS_LIST" | grep -o "$REMOTE_URL")
        if [ "$ACTIVE_REPO" != "$REMOTE_URL" ]; then
            continue
        fi

        if [ -d "${SHARED_ROOT}/.githooks" ]; then
            execute_all_hooks_in "${SHARED_ROOT}/.githooks" "$@" || return 1
        elif [ -d "$SHARED_ROOT" ]; then
            execute_all_hooks_in "$SHARED_ROOT" "$@" || return 1
        fi
    done
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
# Checks if the download_file command needs 
#   credentials over `git crendentials fill`.
#
# Returns:
#   0 if it should use credentials, 1 otherwise
#####################################################
use_credentials(){
    [ "$DOWNLOAD_USE_CREDENTIALS" == "Y" ] || return 1
}

#####################################################
# Parse an url into parts
#   https://stackoverflow.com/a/6174447/293195
# Returns:
#   parsed parts of the url
#####################################################
parse_url(){
    # extract the protocol
    PARSED_PROTOCOL="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    # remove the protocol
    PARSED_URL="$(echo ${1/$PARSED_PROTOCOL/})"
    # extract the user (if any)
    PARSED_USER="$(echo $PARSED_URL | grep @ | cut -d@ -f1)"
    # extract the host and PARSED_PORT
    local hostport
    hostport="$(echo ${PARSED_URL/$PARSED_USER@/} | cut -d/ -f1)"
    # by request host without port    
    PARSED_HOST="$(echo $hostport | sed -e 's,:.*,,g')"
    # by request - try to extract the port
    PARSED_PORT="$(echo $hostport | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
    # extract the path (if any)
    PARSED_PATH="$(echo $PARSED_URL | grep / | cut -d/ -f2-)"
}

#####################################################
# Downloads a file "$1" with `wget` or `curl`
#
# Returns:
#   0 if download succeeded, 1 otherwise
#####################################################
download_file(){

    OUTPUT=""
    if use_credentials ; then
        parse_url "$1"
        PARSED_PROTOCOL=$(echo "$PARSED_PROTOCOL" | sed -e 's@://@@')
        CREDENTIALS=$(echo -e "protocol=$PARSED_PROTOCOL\nhost=$PARSED_HOST\n\n" | git credential fill)
        if [ $? -ne 0 ]; then
            echo "! Getting download credential failed." >&2
            return 1
        fi
        USER=$(echo "$CREDENTIALS" | grep -Eo0 "username=.*$" | cut -d "=" -f2-)
        PASSWORD=$(echo "$CREDENTIALS" | grep -Eo0 "password=.*$" | cut -d "=" -f2-)
    fi

    if curl --version >/dev/null 2>&1; then
        if use_credentials ; then
            OUTPUT=$(curl -fsSL "$1" -u "$USER:$PASSWORD" 2>/dev/null)
        else
            OUTPUT=$(curl -fsSL "$1" 2>/dev/null)
        fi
    elif wget --version >/dev/null 2>&1; then
        if use_credentials ; then
            OUTPUT=$(wget -O- --user="$USER" --password="$PASSWORD" "$1" 2>/dev/null)
        else
            OUTPUT=$(wget -O- "$1" 2>/dev/null)
        fi
    else
        echo "! Cannot download file '$1' - needs either curl or wget" >&2
        return 1 
    fi

    if [ $? -ne 0 ]  ; then
        echo "! Cannot download file '$1' - command failed" >&2
        return 1
    fi

    # Check that its not a HTML file, then something is wrong!
    # We cannot really detect when it failed, curl returns anything 
    # (login page, status code is not reliable?)
    # We use '<''html' to not match the install.sh
    if ( echo "$OUTPUT" | grep -q '<''html' ) ; then
        echo "! Cannot download file '$1' - wrong format!" >&2
        return 1
    fi

    echo "$OUTPUT"
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

    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/install.sh"
    echo "  Downlad $DOWNLOAD_URL ..."
    
    INSTALL_SCRIPT=$(download_file "$DOWNLOAD_URL")

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Failed to check for updates"
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
    LATEST_VERSION=$(echo "$INSTALL_SCRIPT" | grep "^# Version: .*" | head -1 | sed "s/^# Version: //")
}

#####################################################
# Checks if the latest install script is
#   newer than what we have installed already.
#
# Returns:
#   0 if the script is newer, 1 otherwise
#####################################################
is_update_available() {
    CURRENT_VERSION=$(grep "^# Version: .*" "$0" | head -1 | sed "s/^# Version: //")
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
    echo "* There is a new Githooks update available: Version $LATEST_VERSION"
    printf "    Would you like to install it now? [Y/n] "
    read -r EXECUTE_UPDATE </dev/tty

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
        if sh -c "$INSTALL_SCRIPT" -- --single; then
            return 0
        fi
    else
        if sh -c "$INSTALL_SCRIPT"; then
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
