#!/bin/sh
#
# Installs the base Git hook templates from https://github.com/rycus86/githooks
#   and performs some optional setup for existing repositories.
#   See the documentation in the project README for more information.
#
# Version: 1906.291202-f47cdd

# The list of hooks we can manage with this script
MANAGED_HOOK_NAMES="
    applypatch-msg pre-applypatch post-applypatch
    pre-commit prepare-commit-msg commit-msg post-commit
    pre-rebase post-checkout post-merge pre-push
    pre-receive update post-receive post-update
    push-to-checkout pre-auto-gc post-rewrite sendemail-validate
"

# A copy of the base-template.sh file's contents
# shellcheck disable=SC2016
BASE_TEMPLATE_CONTENT='#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.
#
# Version: 1906.291202-f47cdd

# The main update url.
MAIN_DOWNLOAD_URL="https://raw.githubusercontent.com/rycus86/githooks/master"
# If the update url needs credentials, use `git credential fill` to
# get this information.
DOWNLOAD_USE_CREDENTIALS="N"
DOWNLOAD_PROTOCOL="https"
DOWNLOAD_HOST="github.com"

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
# Downloads a file "$1" with `wget` or `curl`
#
# Returns:
#   0 if download succeeded, 1 otherwise
#####################################################
download_file(){

    if use_credentials ; then
        CREDENTIALS=$(echo -e "protocol=$DOWNLOAD_PROTOCOL\nhost=$DOWNLOAD_HOST\n\n" | git credential fill)
        if [ $? -ne 0 ]; then
            echo "! Getting download credential failed."
        fi
        USER=$(echo "$CREDENTIALS" | grep -Eo0 "username=.*$" | cut -d "=" -f2-)
        PASSWORD=$(echo "$CREDENTIALS" | grep -Eo0 "password=.*$" | cut -d "=" -f2-)
    fi

    if curl --version >/dev/null 2>&1; then
        if use_credentials ; then
            curl -fsSL "$1" -u "$USER:$PASSWORD" 2>/dev/null
        else
            curl -fsSL "$1" 2>/dev/null
        fi
        return $?
    elif wget --version >/dev/null 2>&1; then
        if use_credentials ; then
            wget -O- --user="$USER" --password="$PASSWORD" "$1" 2>/dev/null
        else
            wget -O- "$1" 2>/dev/null
        fi
        return $?
    else
        echo "! Cannot download file \"$1\" - needs either curl or wget"
        return 1 
    fi
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
    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/install.sh"

    echo "^ Checking for updates ..."

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
'$1\' - needs either curl or wget"
        return 1 
    fi
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
    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/install.sh"

    echo "^ Checking for updates ..."

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
'username=.*$' | cut -d "=" -f2-)
        PASSWORD=$(echo $CREDENTIALS | grep -Eo0 'password=.*$' | cut -d "=" -f2-)
    fi

    if curl --version >/dev/null 2>&1; then
        if use_credentials ; then
            curl -fsSL "$1" -u "$USER:$PASSWORD" 2>/dev/null
        else
            curl -fsSL "$1" 2>/dev/null
        fi
        return $?
    elif wget --version >/dev/null 2>&1; then
        if use_credentials ; then
            wget -O- --user="$USER" --password="$PASSWORD" "$1" 2>/dev/null
        else
            wget -O- "$1" 2>/dev/null
        fi
        return $?
    else
        echo "! Cannot download file \'$1\' - needs either curl or wget"
        return 1 
    fi
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
    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/install.sh"

    echo "^ Checking for updates ..."

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
'username=.*$' | cut -d "=" -f2-)
        PASSWORD=$(echo $CREDENTIALS | grep -Eo0 'password=.*$' | cut -d "=" -f2-)
    fi

    if curl --version >/dev/null 2>&1; then
        if use_credentials ; then
            curl -fsSL "$1" -u "$USER:$PASSWORD" 2>/dev/null
        else
            curl -fsSL "$1" 2>/dev/null
        fi
        return $?
    elif wget --version >/dev/null 2>&1; then
        if use_credentials ; then
            wget -O- --user="$USER" --password="$PASSWORD" "$1" 2>/dev/null
        else
            wget -O- "$1" 2>/dev/null
        fi
        return $?
    else
        echo "! Cannot download file '$1' - needs either curl or wget"
        return 1 
    fi
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
    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/install.sh"

    echo "^ Checking for updates ..."

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
# Version: 1906.291202-f47cdd

# The main update url.
MAIN_DOWNLOAD_URL="https://raw.githubusercontent.com/rycus86/githooks/master"
# If the update url needs credentials, use `git credential fill` to
# get this information.
DOWNLOAD_USE_CREDENTIALS="N"
DOWNLOAD_PROTOCOL="https"
DOWNLOAD_HOST="github.com"

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
    update      Performs an update check
    readme      Manages the Githooks README in the current repository
    ignore      Manages Githooks ignore files in the current repository
    config      Manages various Githooks configuration
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
# Set up the main variables that
#   we will throughout the hook.
#
# Sets the ${CURRENT_GIT_DIR} variable
#
# Returns:
#   None
#####################################################
set_main_variables() {
    CURRENT_GIT_DIR=$(git rev-parse --git-common-dir)
    if [ "${CURRENT_GIT_DIR}" = "--git-common-dir" ]; then
        CURRENT_GIT_DIR=".git"
    fi
}

#####################################################
# Checks if the current directory is
#   a Git repository or not.
#
# Returns:
#   0 if it is likely a Git repository,
#   1 otherwise
#####################################################
is_running_in_git_repo_root() {
    if ! git status >/dev/null 2>&1; then
        return 1
    fi

    [ -d "${CURRENT_GIT_DIR}" ] || return 1
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
git hooks disable [trigger] [hook-script]
git hooks disable [hook-script]
git hooks disable [trigger]
git hooks disable [-a|--all]
git hooks disable [-r|--reset]

    Disables a hook in the current repository.
    The \`trigger\` parameter should be the name of the Git event if given.
    The \`hook-script\` can be the name of the file to disable, or its
    relative path, or an absolute path, we will try to find it.
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

        echo "! Failed to disable hooks in the current repository"
        exit 1

    elif [ "$1" = "-r" ] || [ "$1" = "--reset" ]; then
        git config --unset githooks.disable

        if ! git config --get githooks.disable; then
            echo "Githooks hook files are not disabled anymore by default" && return
        else
            echo "! Failed to re-enable Githooks hook files"
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

    for HOOK_FILE in $(find "$HOOK_PATH" -type f | grep "/.githooks/"); do
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
git hooks enable [trigger] [hook-script]
git hooks enable [hook-script]
git hooks enable [trigger]

    Enables a hook or hooks in the current repository.
    The \`trigger\` parameter should be the name of the Git event if given.
    The \`hook-script\` can be the name of the file to enable, or its
    relative path, or an absolute path, we will try to find it.
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
git hooks accept [trigger] [hook-script]
git hooks accept [hook-script]
git hooks accept [trigger]

    Accepts a new hook or changes to an existing hook.
    The \`trigger\` parameter should be the name of the Git event if given.
    The \`hook-script\` can be the name of the file to enable, or its
    relative path, or an absolute path, we will try to find it.
"
        return
    fi

    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
        exit 1
    fi

    find_hook_path_to_enable_or_disable "$@" || exit 1
    ensure_checksum_file_exists

    for HOOK_FILE in $(find "$HOOK_PATH" -type f | grep "/.githooks/"); do
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
            echo "  Do not forget to commit and push the trust marker!" &&
            return

        echo "! Failed to mark the current repository as trusted"
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
            echo "! Failed to revoke the trusted setting"
            exit 1
        fi

    elif [ "$1" = "revoke" ] || [ "$1" = "delete" ]; then
        if git config githooks.trust.all N; then
            echo "The current repository is no longer trusted."
        else
            echo "! Failed to revoke the trusted setting"
            exit 1
        fi

        if [ "$1" = "revoke" ]; then
            return
        fi
    fi

    if [ "$1" = "delete" ] || [ -f .githooks/trust-all ]; then
        rm -rf .githooks/trust-all &&
            echo "The trust marker is removed from the repository." &&
            echo "  Do not forget to commit and push the change!" &&
            return

        echo "! Failed to delete the trust marker"
        exit 1
    fi

    echo "! Unknown subcommand: $1"
    echo "  Run \`git hooks trust help\` to see the available options."
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
#   ~/.githooks/shared directory.
#
# Returns the list of paths to the hook files
#   in the shared hook repositories found locally.
#####################################################
list_hooks_in_shared_repos() {
    if [ ! -d ~/.githooks/shared ]; then
        return
    fi

    SHARED_LIST_TYPE="$1"

    for SHARED_ROOT in ~/.githooks/shared/*; do
        if [ ! -d "$SHARED_ROOT" ]; then
            continue
        fi

        REMOTE_URL=$(cd "$SHARED_ROOT" && git config --get remote.origin.url)
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
        [ -w ~/.githooks/shared ] &&
            rm -rf ~/.githooks/shared &&
            echo "All existing shared hook repositories have been deleted locally" &&
            return

        echo "! Cannot delete existing shared hook repositories locally (maybe there is none)"
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

    echo "! Unknown subcommand: \`$1\`"
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
        echo "! Usage: \`git hooks shared add [--global|--local] <git-url>\`"
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

        echo "! Failed to add the new shared hook repository"
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
            echo "  Do not forget to commit the change!" &&
            return

        echo "! Failed to add the new shared hook repository"
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
        echo "! Usage: \`git hooks shared remove [--global|--local] <git-url>\`"
        exit 1
    fi

    if [ -n "$SET_SHARED_GLOBAL" ]; then
        CURRENT_LIST=$(git config --global --get githooks.shared)
        NEW_LIST=""

        IFS=",
        "

        for SHARED_REPO_ITEM in $CURRENT_LIST; do
            if [ "$SHARED_REPO_ITEM" = "$SHARED_REPO_URL" ]; then
                continue
            fi

            if [ -z "$NEW_LIST" ]; then
                NEW_LIST="$SHARED_REPO_ITEM"
            else
                NEW_LIST="${NEW_LIST},${SHARED_REPO_ITEM}"
            fi
        done

        unset IFS

        if [ -z "$NEW_LIST" ]; then
            clear_shared_hook_repos "--global" && return || exit 1
        fi

        git config --global githooks.shared "$NEW_LIST" &&
            echo "The list of shared hook repositories is successfully changed" &&
            return

        echo "! Failed to remove a shared hook repository"
        exit 1

    else
        if ! is_running_in_git_repo_root; then
            echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!"
            exit 1
        fi

        CURRENT_LIST=$(grep -E "^[^#].+$" <"$(pwd)/.githooks/.shared")
        NEW_LIST=""

        IFS=",
        "

        for SHARED_REPO_ITEM in $CURRENT_LIST; do
            if [ "$SHARED_REPO_ITEM" = "$SHARED_REPO_URL" ]; then
                continue
            fi

            if [ -z "$NEW_LIST" ]; then
                NEW_LIST="$SHARED_REPO_ITEM"
            else
                NEW_LIST="${NEW_LIST}
${SHARED_REPO_ITEM}"
            fi
        done

        unset IFS

        if [ -z "$NEW_LIST" ]; then
            clear_shared_hook_repos "--local" && return || exit 1
        fi

        echo "$NEW_LIST" >"$(pwd)/.githooks/.shared" &&
            echo "The list of shared hook repositories is successfully changed" &&
            echo "  Do not forget to commit the change!" &&
            return

        echo "! Failed to remove a shared hook repository"
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
        echo "! One of the following must be used:"
        echo "  git hooks shared clear --global"
        echo "  git hooks shared clear --local"
        echo "  git hooks shared clear --all"
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
        echo "! There were some problems clearing the shared hook repository list"
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
            echo "! Unknown list option: $ARG"
            exit 1
            ;;
        esac
    done

    IFS=",
    "

    if [ -n "$LIST_GLOBAL" ]; then
        echo "Global shared hook repositories:"

        if [ -z "$(git config --global --get githooks.shared)" ]; then
            echo "  - None"
        else
            for LIST_ITEM in $(git config --global --get githooks.shared); do
                NORMALIZED_NAME=$(echo "$LIST_ITEM" |
                    sed -E "s#.*[:/](.+/.+)\\.git#\\1#" |
                    sed -E "s/[^a-zA-Z0-9]/_/g")

                if [ -d ~/.githooks/shared/"$NORMALIZED_NAME"/.git ]; then
                    if [ "$(cd ~/.githooks/shared/"$NORMALIZED_NAME" && git config --get remote.origin.url)" = "$LIST_ITEM" ]; then
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
            done
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

            echo "$SHARED_REPOS_LIST" | while read -r LIST_ITEM; do
                NORMALIZED_NAME=$(echo "$LIST_ITEM" |
                    sed -E "s#.*[:/](.+/.+)\\.git#\\1#" |
                    sed -E "s/[^a-zA-Z0-9]/_/g")

                if [ -d ~/.githooks/shared/"$NORMALIZED_NAME"/.git ]; then
                    if [ "$(cd ~/.githooks/shared/"$NORMALIZED_NAME" && git config --get remote.origin.url)" = "$LIST_ITEM" ]; then
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
            done
        fi
    fi

    unset IFS
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
# Updates the shared hooks repositories
#   on the list passed in on the first argument.
#####################################################
update_shared_hooks_in() {
    SHARED_REPOS_LIST="$1"

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
        echo "! Failed to fetch the latest install script"
        echo "  You can retry manually using one of the alternative methods,"
        echo "    see them here: https://github.com/rycus86/githooks#installation"
        exit 1
    fi

    read_latest_version_number

    echo "  Githooks install script downloaded: Version $LATEST_VERSION"
    echo

    if ! execute_install_script; then
        echo "! Failed to execute the installation"
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

        echo "! Failed to enable automatic updates" && exit 1

    elif [ "$1" = "disable" ]; then
        git config --global githooks.autoupdate.enabled N &&
            echo "Automatic update checks have been disabled" &&
            return

        echo "! Failed to disable automatic updates" && exit 1

    elif [ -n "$1" ] && [ "$1" != "force" ]; then
        echo "! Invalid operation: \`$1\`" && exit 1

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
# Downloads a file "$1" with `wget` or `curl`
#
# Returns:
#   0 if download succeeded, 1 otherwise
#####################################################
download_file(){

    if use_credentials ; then
        CREDENTIALS=$(echo -e "protocol=$DOWNLOAD_PROTOCOL\nhost=$DOWNLOAD_HOST\n\n" | git credential fill)
        if [ $? -ne 0 ]; then
            echo "! Getting download credential failed."
        fi
        USER=$(echo "$CREDENTIALS" | grep -Eo0 "username=.*$" | cut -d "=" -f2-)
        PASSWORD=$(echo "$CREDENTIALS" | grep -Eo0 "password=.*$" | cut -d "=" -f2-)
    fi

    if curl --version >/dev/null 2>&1; then
        if use_credentials ; then
            curl -fsSL "$1" -u "$USER:$PASSWORD" 2>/dev/null
        else
            curl -fsSL "$1" 2>/dev/null
        fi
        return $?
    elif wget --version >/dev/null 2>&1; then
        if use_credentials ; then
            wget -O- --user="$USER" --password="$PASSWORD" "$1" 2>/dev/null
        else
            wget -O- "$1" 2>/dev/null
        fi
        return $?
    else
        echo "! Cannot download file \"$1\" - needs either curl or wget"
        return 1
    fi
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
fetch_latest_install_script() {

    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/install.sh"

    INSTALL_SCRIPT=$(download_file "$DOWNLOAD_URL")

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
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
        echo "! This repository already seems to have a Githooks README."
        echo "  If you would like to replace it with the latest one, please run \`git hooks readme update\`"
        exit 1
    fi

    if ! fetch_latest_readme; then
        exit 1
    fi

    mkdir -p "$(pwd)/.githooks" &&
        printf "%s" "$README_CONTENTS" >"$(pwd)/.githooks/README.md" &&
        echo "The README file is updated, do not forget to commit and push it!" ||
        echo "! Failed to update the README file in the current repository"
}

#####################################################
# Loads the contents of the latest Githooks README
#   into a variable.
#
# Sets the ${README_CONTENTS} variable
#
# Returns:
#   1 if failed the load the contents, 0 otherwise
#####################################################
fetch_latest_readme() {
    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/.githooks/README.md"

    INSTALL_SCRIPT=$(download_file "$DOWNLOAD_URL")

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Failed to fetch the latest README"
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
        echo "! Missing pattern parameter"
        exit 1
    fi

    if ! mkdir -p "$TARGET_DIR" && touch "$TARGET_DIR/.ignore"; then
        echo "! Failed to prepare the ignore file at $TARGET_DIR/.ignore"
        exit 1
    fi

    [ -f "$TARGET_DIR/.ignore" ] &&
        echo "" >>"$TARGET_DIR/.ignore"

    for PATTERN in "$@"; do
        if ! echo "$PATTERN" >>"$TARGET_DIR/.ignore"; then
            echo "! Failed to update the ignore file at $TARGET_DIR/.ignore"
            exit 1
        fi
    done

    echo "The ignore file at $TARGET_DIR/.ignore is updated"
    echo "  Do not forget to commit the changes!"
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
"
        return
    fi

    CONFIG_OPERATION="$1"

    if [ "$CONFIG_OPERATION" = "list" ]; then
        if [ "$2" = "--local" ] && ! is_running_in_git_repo_root; then
            echo "! Local configuration can only be printed from a Git repository"
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
    *)
        manage_configuration "help"
        echo "! Invalid configuration option: \`$2\`"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
        git config githooks.single.install yes
    elif [ "$1" = "reset" ]; then
        git config --unset githooks.single.install
    elif [ "$1" = "print" ]; then
        if read_single_repo_information && is_single_repo; then
            echo "The current repository is marked as a single installation"
        else
            echo "The current repository is NOT marked as a single installation"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
            echo "! Missing <path> parameter"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
            echo "! Missing <git-url> parameter"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`accept\`, \`deny\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`enable\`, \`disable\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`reset\` or \`print\`)"
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

    CURRENT_VERSION=$(grep "^# Version: .*" "$0" | head -1 | sed "s/^# Version: //")

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
    "version")
        print_current_version_number "$@"
        ;;
    "help")
        print_help
        ;;
    *)
        print_help
        [ -n "$CMD" ] && echo "! Unknown command: $CMD"
        exit 1
        ;;
    esac
}

# Set the main variables we will need
set_main_variables
# Choose and execute the command
choose_command "$@"
'$1' - needs either curl or wget"
        return 1
    fi
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
fetch_latest_install_script() {

    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/install.sh"

    INSTALL_SCRIPT=$(download_file "$DOWNLOAD_URL")

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
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
        echo "! This repository already seems to have a Githooks README."
        echo "  If you would like to replace it with the latest one, please run \`git hooks readme update\`"
        exit 1
    fi

    if ! fetch_latest_readme; then
        exit 1
    fi

    mkdir -p "$(pwd)/.githooks" &&
        printf "%s" "$README_CONTENTS" >"$(pwd)/.githooks/README.md" &&
        echo "The README file is updated, do not forget to commit and push it!" ||
        echo "! Failed to update the README file in the current repository"
}

#####################################################
# Loads the contents of the latest Githooks README
#   into a variable.
#
# Sets the ${README_CONTENTS} variable
#
# Returns:
#   1 if failed the load the contents, 0 otherwise
#####################################################
fetch_latest_readme() {
    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/.githooks/README.md"

    INSTALL_SCRIPT=$(download_file "$DOWNLOAD_URL")

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Failed to fetch the latest README"
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
        echo "! Missing pattern parameter"
        exit 1
    fi

    if ! mkdir -p "$TARGET_DIR" && touch "$TARGET_DIR/.ignore"; then
        echo "! Failed to prepare the ignore file at $TARGET_DIR/.ignore"
        exit 1
    fi

    [ -f "$TARGET_DIR/.ignore" ] &&
        echo "" >>"$TARGET_DIR/.ignore"

    for PATTERN in "$@"; do
        if ! echo "$PATTERN" >>"$TARGET_DIR/.ignore"; then
            echo "! Failed to update the ignore file at $TARGET_DIR/.ignore"
            exit 1
        fi
    done

    echo "The ignore file at $TARGET_DIR/.ignore is updated"
    echo "  Do not forget to commit the changes!"
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
"
        return
    fi

    CONFIG_OPERATION="$1"

    if [ "$CONFIG_OPERATION" = "list" ]; then
        if [ "$2" = "--local" ] && ! is_running_in_git_repo_root; then
            echo "! Local configuration can only be printed from a Git repository"
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
    *)
        manage_configuration "help"
        echo "! Invalid configuration option: \`$2\`"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
        git config githooks.single.install yes
    elif [ "$1" = "reset" ]; then
        git config --unset githooks.single.install
    elif [ "$1" = "print" ]; then
        if read_single_repo_information && is_single_repo; then
            echo "The current repository is marked as a single installation"
        else
            echo "The current repository is NOT marked as a single installation"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
            echo "! Missing <path> parameter"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
            echo "! Missing <git-url> parameter"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`accept\`, \`deny\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`enable\`, \`disable\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`reset\` or \`print\`)"
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

    CURRENT_VERSION=$(grep "^# Version: .*" "$0" | head -1 | sed "s/^# Version: //")

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
    "version")
        print_current_version_number "$@"
        ;;
    "help")
        print_help
        ;;
    *)
        print_help
        [ -n "$CMD" ] && echo "! Unknown command: $CMD"
        exit 1
        ;;
    esac
}

# Set the main variables we will need
set_main_variables
# Choose and execute the command
choose_command "$@"
'username=.*$\' | cut -d "=" -f2-)
        PASSWORD=$(echo $CREDENTIALS | grep -Eo0 \'password=.*$\' | cut -d "=" -f2-)
    fi

    if curl --version >/dev/null 2>&1; then
        if use_credentials ; then
            curl -fsSL "$1" -u "$USER:$PASSWORD" 2>/dev/null
        else
            curl -fsSL "$1" 2>/dev/null
        fi
        return $?
    elif wget --version >/dev/null 2>&1; then
        if use_credentials ; then
            wget -O- --user="$USER" --password="$PASSWORD" "$1" 2>/dev/null
        else
            wget -O- "$1" 2>/dev/null
        fi
        return $?
    else
        echo "! Cannot download file '$1' - needs either curl or wget"
        return 1
    fi
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
fetch_latest_install_script() {

    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/install.sh"

    INSTALL_SCRIPT=$(download_file "$DOWNLOAD_URL")

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
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
        echo "! This repository already seems to have a Githooks README."
        echo "  If you would like to replace it with the latest one, please run \`git hooks readme update\`"
        exit 1
    fi

    if ! fetch_latest_readme; then
        exit 1
    fi

    mkdir -p "$(pwd)/.githooks" &&
        printf "%s" "$README_CONTENTS" >"$(pwd)/.githooks/README.md" &&
        echo "The README file is updated, do not forget to commit and push it!" ||
        echo "! Failed to update the README file in the current repository"
}

#####################################################
# Loads the contents of the latest Githooks README
#   into a variable.
#
# Sets the ${README_CONTENTS} variable
#
# Returns:
#   1 if failed the load the contents, 0 otherwise
#####################################################
fetch_latest_readme() {
    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/.githooks/README.md"

    INSTALL_SCRIPT=$(download_file "$DOWNLOAD_URL")

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Failed to fetch the latest README"
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
        echo "! Missing pattern parameter"
        exit 1
    fi

    if ! mkdir -p "$TARGET_DIR" && touch "$TARGET_DIR/.ignore"; then
        echo "! Failed to prepare the ignore file at $TARGET_DIR/.ignore"
        exit 1
    fi

    [ -f "$TARGET_DIR/.ignore" ] &&
        echo "" >>"$TARGET_DIR/.ignore"

    for PATTERN in "$@"; do
        if ! echo "$PATTERN" >>"$TARGET_DIR/.ignore"; then
            echo "! Failed to update the ignore file at $TARGET_DIR/.ignore"
            exit 1
        fi
    done

    echo "The ignore file at $TARGET_DIR/.ignore is updated"
    echo "  Do not forget to commit the changes!"
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
"
        return
    fi

    CONFIG_OPERATION="$1"

    if [ "$CONFIG_OPERATION" = "list" ]; then
        if [ "$2" = "--local" ] && ! is_running_in_git_repo_root; then
            echo "! Local configuration can only be printed from a Git repository"
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
    *)
        manage_configuration "help"
        echo "! Invalid configuration option: \`$2\`"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
        git config githooks.single.install yes
    elif [ "$1" = "reset" ]; then
        git config --unset githooks.single.install
    elif [ "$1" = "print" ]; then
        if read_single_repo_information && is_single_repo; then
            echo "The current repository is marked as a single installation"
        else
            echo "The current repository is NOT marked as a single installation"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
            echo "! Missing <path> parameter"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
            echo "! Missing <git-url> parameter"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`accept\`, \`deny\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`enable\`, \`disable\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`reset\` or \`print\`)"
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

    CURRENT_VERSION=$(grep "^# Version: .*" "$0" | head -1 | sed "s/^# Version: //")

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
    "version")
        print_current_version_number "$@"
        ;;
    "help")
        print_help
        ;;
    *)
        print_help
        [ -n "$CMD" ] && echo "! Unknown command: $CMD"
        exit 1
        ;;
    esac
}

# Set the main variables we will need
set_main_variables
# Choose and execute the command
choose_command "$@"
'username=.*$' | cut -d "=" -f2-)
        PASSWORD=$(echo $CREDENTIALS | grep -Eo0 'password=.*$' | cut -d "=" -f2-)
    fi

    if curl --version >/dev/null 2>&1; then
        if use_credentials ; then
            curl -fsSL "$1" -u "$USER:$PASSWORD" 2>/dev/null
        else
            curl -fsSL "$1" 2>/dev/null
        fi
        return $?
    elif wget --version >/dev/null 2>&1; then
        if use_credentials ; then
            wget -O- --user="$USER" --password="$PASSWORD" "$1" 2>/dev/null
        else
            wget -O- "$1" 2>/dev/null
        fi
        return $?
    else
        echo "! Cannot download file '$1' - needs either curl or wget"
        return 1
    fi
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
fetch_latest_install_script() {

    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/install.sh"

    INSTALL_SCRIPT=$(download_file "$DOWNLOAD_URL")

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
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
        echo "! This repository already seems to have a Githooks README."
        echo "  If you would like to replace it with the latest one, please run \`git hooks readme update\`"
        exit 1
    fi

    if ! fetch_latest_readme; then
        exit 1
    fi

    mkdir -p "$(pwd)/.githooks" &&
        printf "%s" "$README_CONTENTS" >"$(pwd)/.githooks/README.md" &&
        echo "The README file is updated, do not forget to commit and push it!" ||
        echo "! Failed to update the README file in the current repository"
}

#####################################################
# Loads the contents of the latest Githooks README
#   into a variable.
#
# Sets the ${README_CONTENTS} variable
#
# Returns:
#   1 if failed the load the contents, 0 otherwise
#####################################################
fetch_latest_readme() {
    DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/.githooks/README.md"

    INSTALL_SCRIPT=$(download_file "$DOWNLOAD_URL")

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Failed to fetch the latest README"
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
        echo "! Missing pattern parameter"
        exit 1
    fi

    if ! mkdir -p "$TARGET_DIR" && touch "$TARGET_DIR/.ignore"; then
        echo "! Failed to prepare the ignore file at $TARGET_DIR/.ignore"
        exit 1
    fi

    [ -f "$TARGET_DIR/.ignore" ] &&
        echo "" >>"$TARGET_DIR/.ignore"

    for PATTERN in "$@"; do
        if ! echo "$PATTERN" >>"$TARGET_DIR/.ignore"; then
            echo "! Failed to update the ignore file at $TARGET_DIR/.ignore"
            exit 1
        fi
    done

    echo "The ignore file at $TARGET_DIR/.ignore is updated"
    echo "  Do not forget to commit the changes!"
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
"
        return
    fi

    CONFIG_OPERATION="$1"

    if [ "$CONFIG_OPERATION" = "list" ]; then
        if [ "$2" = "--local" ] && ! is_running_in_git_repo_root; then
            echo "! Local configuration can only be printed from a Git repository"
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
    *)
        manage_configuration "help"
        echo "! Invalid configuration option: \`$2\`"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
        git config githooks.single.install yes
    elif [ "$1" = "reset" ]; then
        git config --unset githooks.single.install
    elif [ "$1" = "print" ]; then
        if read_single_repo_information && is_single_repo; then
            echo "The current repository is marked as a single installation"
        else
            echo "The current repository is NOT marked as a single installation"
        fi
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
            echo "! Missing <path> parameter"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
            echo "! Missing <git-url> parameter"
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
        echo "! Invalid operation: \`$1\` (use \`set\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`accept\`, \`deny\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`enable\`, \`disable\`, \`reset\` or \`print\`)"
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
        echo "! Invalid operation: \`$1\` (use \`reset\` or \`print\`)"
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

    CURRENT_VERSION=$(grep "^# Version: .*" "$0" | head -1 | sed "s/^# Version: //")

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
    "version")
        print_current_version_number "$@"
        ;;
    "help")
        print_help
        ;;
    *)
        print_help
        [ -n "$CMD" ] && echo "! Unknown command: $CMD"
        exit 1
        ;;
    esac
}

# Set the main variables we will need
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
    parse_command_line_arguments "$@"

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
    if setup_automatic_update_checks; then
        echo # For visual separation
    fi

    # Install the hooks into existing local repositories
    if is_single_repo_install; then
        install_hooks_into_repo "$(pwd)" || return 1
    else
        install_into_existing_repositories
    fi

    echo # For visual separation

    # Set up shared hook repositories if needed
    if ! is_single_repo_install && ! is_non_interactive; then
        setup_shared_hook_repositories
        echo # For visual separation
    fi
}

############################################################
# Set up variables based on command line arguments.
#
# Sets ${DRY_RUN} for --dry-run
# Sets ${NON_INTERACTIVE} for --non-interactive
# Sets ${SINGLE_REPO_INSTALL} for --single
#
# Returns:
#   None
############################################################
parse_command_line_arguments() {
    for p in "$@"; do
        if [ "$p" = "--dry-run" ]; then
            DRY_RUN="yes"
        elif [ "$p" = "--non-interactive" ]; then
            NON_INTERACTIVE="yes"
        elif [ "$p" = "--single" ]; then
            SINGLE_REPO_INSTALL="yes"
        fi
    done
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
# Checks whether the current working directory
#   is a Git repository or not.
#
# Returns:
#   1 if failed, 0 otherwise
############################################################
ensure_running_in_git_repo() {
    if ! git status >/dev/null 2>&1; then
        echo "! The current directory is not Git repository"
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
    git config githooks.single.install yes
}

############################################################
# Prepare the target template directory variable,
#   and make sure it points to a directory when set.
#
# Resets and sets the ${TARGET_TEMPLATE_DIR} variable.
#
# Returns:
#   1 if failed, 0 otherwise
############################################################
prepare_target_template_directory() {
    TARGET_TEMPLATE_DIR=""

    find_git_hook_templates

    if [ ! -d "$TARGET_TEMPLATE_DIR" ]; then
        echo "Git hook templates directory not found"
        return 1
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
    mark_directory_as_target "$(git config --get init.templateDir)" "hooks"
    if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi

    # 3. from the default location
    mark_directory_as_target "/usr/share/git-core/templates/hooks"
    if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi

    # 4. try to search for it on disk
    printf 'Could not find the Git hook template directory. '
    printf 'Do you want to search for it? [y/N] '
    read -r DO_SEARCH

    if [ "${DO_SEARCH}" = "y" ] || [ "${DO_SEARCH}" = "Y" ]; then
        search_for_templates_dir

        if [ "$TARGET_TEMPLATE_DIR" != "" ]; then
            printf 'Do you want to set this up as the Git template directory for future use? [y/N] '
            read -r MARK_AS_TEMPLATES

            if [ "$MARK_AS_TEMPLATES" = "y" ] || [ "$MARK_AS_TEMPLATES" = "Y" ]; then
                TEMPLATE_DIR=$(dirname "$TARGET_TEMPLATE_DIR")
                if ! git config --global init.templateDir "$TEMPLATE_DIR"; then
                    echo "! Failed to set it up as Git template directory"
                fi
            fi

            return
        fi
    fi

    # 5. set up as new
    printf "Do you want to set up a new Git templates folder? [y/N] "
    read -r SETUP_NEW_FOLDER

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

    printf 'Git hook template directory not found in /usr. '
    printf 'Do you want to keep searching? [y/N] '
    read -r DO_SEARCH

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

    for HIT in $(find "$START_DIR" 2>/dev/null | grep "templates/hooks/pre-commit.sample"); do
        HIT=$(dirname "$HIT")

        if [ ! -w "$HIT" ]; then
            echo "Skipping non-writable directory: $HIT"
            continue
        fi

        printf -- "- Is it %s ? [y/N] " "$HIT"
        read -r ACCEPT

        if [ "$ACCEPT" = "y" ] || [ "$ACCEPT" = "Y" ]; then
            TARGET_TEMPLATE_DIR="$HIT"
            return
        fi
    done
}

############################################################
# Setup a new Git templates folder.
#
# Returns:
#   None
############################################################
setup_new_templates_folder() {
    # shellcheck disable=SC2088
    DEFAULT_TARGET="~/.githooks/templates"
    printf "Enter the target folder: [%s] " "$DEFAULT_TARGET"
    read -r USER_TEMPLATES

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
            git config --global init.templateDir "$USER_TEMPLATES"
        else
            echo "! Failed to set up the new Git templates folder"
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

    for HOOK in $MANAGED_HOOK_NAMES; do
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
            echo "! Failed to setup the $HOOK template at $HOOK_TEMPLATE"
            return 1
        fi
    done

    return 0
}

############################################################
# Installs the command line helper tool at
#   ~/.githooks/bin/githooks and adds a Git alias for it.
#
# Returns:
#   None
############################################################
install_command_line_tool() {
    mkdir -p "$HOME/.githooks/bin" &&
        echo "$CLI_TOOL_CONTENT" >"$HOME/.githooks/bin/githooks" &&
        chmod +x "$HOME/.githooks/bin/githooks" &&
        git config --global alias.hooks "!$HOME/.githooks/bin/githooks" &&
        echo "The command line helper tool is installed at ${HOME}/.githooks/bin/githooks, and it is now available as 'git hooks <cmd>'" &&
        return

    echo "Failed to setup the command line helper automatically. If you'd like to do it manually, install the 'cli.sh' file from the repository into a folder on your PATH environment variable, and make it executable."
    echo "Direct link to the script: https://raw.githubusercontent.com/rycus86/githooks/master/cli.sh"
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
            echo "! Failed to enable automatic update checks"
        fi
    else
        echo "If you change your mind in the future, you can enable it by running:"
        echo "  \$ git hooks update enable"
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
        echo "! '$START_DIR' is not a directory"
        echo "  Existing repositories won't get the Githooks hooks."
        return
    fi

    git config --global githooks.previous.searchdir "$RAW_START_DIR"

    LOCAL_REPOSITORY_LIST=$(find "$START_DIR" -type d -name .git 2>/dev/null)

    # Sort the list if we can
    if sort --help >/dev/null 2>&1; then
        LOCAL_REPOSITORY_LIST=$(echo "$LOCAL_REPOSITORY_LIST" | sort)
    fi

    for EXISTING in $LOCAL_REPOSITORY_LIST; do
        EXISTING_REPO_ROOT=$(dirname "$EXISTING")
        install_hooks_into_repo "$EXISTING_REPO_ROOT"
    done

    return
}

############################################################
# Install the new Git hook templates into an existing
#   local repository, given by the first parameter.
#
# Returns:
#   0 on success, 1 on failure
############################################################
install_hooks_into_repo() {
    TARGET_ROOT="$1"
    TARGET="${TARGET_ROOT}/.git"

    if [ ! -w "${TARGET}/hooks" ]; then
        # Try to create the .git/hooks folder
        if ! mkdir "${TARGET}/hooks" 2>/dev/null; then
            return 1
        fi
    fi

    INSTALLED="no"

    for HOOK_NAME in $MANAGED_HOOK_NAMES; do
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
                if ! mv "$TARGET_HOOK" "${TARGET_HOOK}.replaced.githook"; then
                    HAD_FAILURE=Y
                    echo "! Failed to save the existing hook at $TARGET_HOOK"
                    continue
                fi
            fi
        fi

        if echo "$BASE_TEMPLATE_CONTENT" >"$TARGET_HOOK" && chmod +x "$TARGET_HOOK"; then
            INSTALLED="yes"
        else
            HAD_FAILURE=Y
            echo "! Failed to install $TARGET_HOOK"
        fi
    done

    # Offer to setup the intro README if running in interactive mode
    if is_non_interactive; then
        true # Let's skip this in non-interactive mode to avoid polluting the local repos with README files

    elif [ ! -f "${TARGET_ROOT}/.githooks/README.md" ]; then
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

    if [ "$INSTALLED" = "yes" ]; then
        if is_dry_run; then
            echo "[Dry run] Hooks would have been installed into $TARGET_ROOT"
        else
            echo "Hooks installed into $TARGET_ROOT"
        fi
    fi

    if [ "$HAD_FAILURE" = "Y" ]; then
        return 1
    else
        return 0
    fi
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

    read -r DO_SETUP
    if [ "$DO_SETUP" != "y" ] && [ "$DO_SETUP" != "Y" ]; then return; fi

    echo "OK, let's input them one-by-one and leave the input empty to stop."

    SHARED_REPOS_LIST=""
    while true; do
        printf "Enter the clone URL of a shared repository: "
        read -r SHARED_REPO
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
        echo "! Failed to set up the shared hook repositories"
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
