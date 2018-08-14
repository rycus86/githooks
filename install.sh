#!/bin/sh
#
# Installs the base Git hook templates from https://github.com/rycus86/githooks
#   and performs some optional setup for existing repositories.
#   See the documentation in the project README for more information.

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
# Version: 1808.142252-4d09ae

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
        TRUST_ALL_CONFIG=$(git config --local --get githooks.trust.all)
        TRUST_ALL_RESULT=$?

        # shellcheck disable=SC2181
        if [ $TRUST_ALL_RESULT -ne 0 ]; then
            echo "! This repository wants you to trust all current and future hooks without prompting"
            printf "  Do you want to allow running every current and future hooks? [y/N] "
            read -r TRUST_ALL_HOOKS </dev/tty

            if [ "$TRUST_ALL_HOOKS" = "y" ] || [ "$TRUST_ALL_HOOKS" = "Y" ]; then
                git config githooks.trust.all Y
                TRUSTED_REPO="Y"
            else
                git config githooks.trust.all N
            fi
        elif [ $TRUST_ALL_RESULT -eq 0 ] && [ "$TRUST_ALL_CONFIG" = "Y" ]; then
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

    UPDATES_ENABLED=$(git config --get githooks.autoupdate.enabled)
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
            IS_SINGLE_REPO=$(git config --get --local githooks.single.install)

            if [ "$IS_SINGLE_REPO" = "yes" ]; then
                if sh -c "$INSTALL_SCRIPT" -- --single; then
                    return
                fi
            else
                if sh -c "$INSTALL_SCRIPT"; then
                    return
                fi
            fi
        fi

        if [ "$IS_SINGLE_REPO" != "yes" ]; then
            GLOBAL_CONFIG="--global"
        fi

        echo "  If you would like to disable auto-updates, run:"
        echo "    \$ git config ${GLOBAL_CONFIG} githooks.autoupdate.enabled N"
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
'

############################################################
# Check if the install script is
#   running in 'dry-run' mode.
#
# Returns:
#   'yes' or 'no' as string
############################################################
is_dry_run() {
    for p in "$@"; do
        if [ "$p" = "--dry-run" ]; then
            echo "yes"
            return
        fi
    done

    echo "no"
}

############################################################
# Check if the install script is
#   running in non-interactive mode.
#
# Returns:
#   0 in non-interactive mode, 1 otherwise
############################################################
is_non_interactive() {
    for p in "$@"; do
        if [ "$p" = "--non-interactive" ]; then
            return 0
        fi
    done

    return 1
}

############################################################
# Check if the install script is
#   running in for a single repository without templates.
#
# Returns:
#   'yes' or 'no' as string
############################################################
is_single_repo_install() {
    for p in "$@"; do
        if [ "$p" = "--single" ]; then
            echo "yes"
            return
        fi
    done

    echo "no"
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
    DEFAULT_TARGET="~/.git-templates"
    printf "Enter the target folder: [%s] " "$DEFAULT_TARGET"
    read -r USER_TEMPLATES

    if [ "$USER_TEMPLATES" = "" ]; then
        USER_TEMPLATES="$DEFAULT_TARGET"
    fi

    TILDE_REPLACED=$(echo "$USER_TEMPLATES" | awk 'gsub("~", "'"$HOME"'", $0)')
    if [ -z "$TILDE_REPLACED" ]; then
        TILDE_REPLACED="$USER_TEMPLATES"
    fi

    if [ "$DRY_RUN" != "yes" ]; then
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
            printf "Would you like to re-enable them, done once a day after a commit? [Y/n] "
        fi
    else
        printf "Would you like to enable automatic update checks, done once a day after a commit? [Y/n] "
    fi

    read -r DO_AUTO_UPDATES
    if [ -z "$DO_AUTO_UPDATES" ] || [ "$DO_AUTO_UPDATES" = "y" ] || [ "$DO_AUTO_UPDATES" = "Y" ]; then
        if [ "$SINGLE_REPO_INSTALL" != "yes" ]; then
            GLOBAL_CONFIG="--global"
        fi

        if [ "$DRY_RUN" = "yes" ]; then
            echo "[Dry run] Automatic update checks would have been enabled"
        elif git config ${GLOBAL_CONFIG} githooks.autoupdate.enabled Y; then
            echo "Automatic update checks are now enabled"
        else
            echo "! Failed to enable automatic update checks"
        fi
    else
        echo "If you change your mind in the future, you can enable it by running:"
        echo "  \$ git config --global githooks.autoupdate.enabled Y"
    fi
}

############################################################
# Install the new Git hook templates into the
#   existing local repositories.
#
# Returns:
#   0 on success, 1 on failure
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

    printf 'Do you want to install the hooks into existing repositories? %s ' "$QUESTION_PROMPT"
    read -r DO_INSTALL

    if [ "$DO_INSTALL" != "y" ] && [ "$DO_INSTALL" != "Y" ]; then
        if [ "$HAS_PRE_START_DIR" != "Y" ] || [ -n "$DO_INSTALL" ]; then
            return 0
        fi
    fi

    printf 'Where do you want to start the search? [%s] ' "$PRE_START_DIR"
    read -r START_DIR

    if [ "$START_DIR" = "" ]; then
        START_DIR="$PRE_START_DIR"
    fi

    TILDE_REPLACED=$(echo "$START_DIR" | awk 'gsub("~", "'"$HOME"'", $0)')
    if [ -n "$TILDE_REPLACED" ]; then
        START_DIR="$TILDE_REPLACED"
    fi

    if [ ! -d "$START_DIR" ]; then
        echo "'$START_DIR' is not a directory"
        return 1
    fi

    git config --global githooks.previous.searchdir "$START_DIR"

    find "$START_DIR" -type d -name .git 2>/dev/null | while IFS= read -r EXISTING; do
        install_hooks_into_repo "$EXISTING"
    done

    return 0
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

    if [ ! -w "${TARGET}/hooks" ]; then
        # Try to create the .git/hooks folder
        if ! mkdir "${TARGET}/hooks" 2>/dev/null; then
            return 1
        fi
    fi

    INSTALLED="no"

    for HOOK_NAME in $MANAGED_HOOK_NAMES; do
        if [ "$DRY_RUN" = "yes" ]; then
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

    if [ "$INSTALLED" = "yes" ]; then
        TARGET_DIR=$(dirname "$TARGET")

        if [ "$DRY_RUN" = "yes" ]; then
            echo "[Dry run] Hooks would have been installed into $TARGET_DIR"
        else
            echo "Hooks installed into $TARGET_DIR"
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

# Check if we're running in dry-run mode
DRY_RUN=$(is_dry_run "$@")

if is_non_interactive "$@"; then
    exec </dev/null
fi

SINGLE_REPO_INSTALL=$(is_single_repo_install "$@")

if [ "$SINGLE_REPO_INSTALL" = "yes" ]; then
    # Make sure we are in a git repo
    if ! git status >/dev/null 2>&1; then
        echo "! The current directory is not Git repository"
        exit 1
    fi

    git config githooks.single.install yes

else
    # Find the Git hook template directory to install into
    TARGET_TEMPLATE_DIR=""

    find_git_hook_templates

    if [ ! -d "$TARGET_TEMPLATE_DIR" ]; then
        echo "Git hook templates directory not found"
        exit 1
    fi

    # Setup the new hooks in the template directory
    if [ "$DRY_RUN" = "yes" ]; then
        echo "[Dry run] Would install Git hook templates into $TARGET_TEMPLATE_DIR"

    elif ! setup_hook_templates; then
        exit 1

    fi

    echo # For visual separation

fi

# Automatic updates
if setup_automatic_update_checks; then
    echo # For visual separation
fi

# Install the hooks into existing local repositories
if [ "$SINGLE_REPO_INSTALL" = "yes" ]; then
    if ! install_hooks_into_repo "$(pwd)/.git"; then

        exit 1
    fi

else
    if ! install_into_existing_repositories; then
        exit 1
    fi

fi

echo # For visual separation

if [ "$SINGLE_REPO_INSTALL" != "yes" ]; then
    # Set up shared hook repositories
    setup_shared_hook_repositories

    echo # For visual separation
fi

echo "All done! Enjoy!

Please support the project by starring the project at https://github.com/rycus86/githooks, and report bugs or missing features or improvements as issues. Thanks!"
