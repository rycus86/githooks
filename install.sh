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

    # get hash of the hook contents
    if ! MD5_HASH=$(md5 -r "$HOOK_PATH" 2>/dev/null); then
        MD5_HASH=$(md5sum "$HOOK_PATH" 2>/dev/null)
    fi
    MD5_HASH=$(echo "$MD5_HASH" | awk "{ print \$1 }")
    CURRENT_HASHES=$(grep "$HOOK_PATH" .git/.githooks.checksum 2>/dev/null)
    # check against the previous hash
    if ! echo "$CURRENT_HASHES" | grep -q "$MD5_HASH $HOOK_PATH" >/dev/null 2>&1; then
        # assign a terminal
        [ -f /dev/tty ] && exec </dev/tty

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
            read -r ACCEPT_CHANGES

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

HOOK_NAME=$(basename "$0")
HOOK_FOLDER=$(dirname "$0")
ACCEPT_CHANGES=

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
    printf 'Do you want to search for it? [yN] '
    read -r DO_SEARCH

    if [ "${DO_SEARCH}" = "y" ] || [ "${DO_SEARCH}" = "Y" ]; then
        search_for_templates_dir

        if [ "$TARGET_TEMPLATE_DIR" != "" ]; then
            printf 'Do you want to set this up as the Git template directory for future use? [yN] '
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
    printf "Do you want to set up a new Git templates folder? [yN] "
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
    printf 'Do you want to keep searching? [yN] '
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

        printf -- "- Is it %s ? [yN] " "$HIT"
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
            echo "Failed to set up the new Git templates folder"
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
            echo "Failed to setup the $HOOK template at $HOOK_TEMPLATE"
            return 1
        fi
    done

    return 0
}

############################################################
# Install the new Git hook templates into the
#   existing local repositories.
#
# Returns:
#   0 on success, 1 on failure
############################################################
install_into_existing_repositories() {
    printf 'Do you want to install the hooks into existing repositories? [yN] '
    read -r DO_INSTALL
    if [ "$DO_INSTALL" != "y" ] && [ "$DO_INSTALL" != "Y" ]; then return 0; fi

    printf 'Where do you want to start the search? [%s] ' ~
    read -r START_DIR

    if [ "$START_DIR" = "" ]; then
        START_DIR="$HOME"
    fi

    TILDE_REPLACED=$(echo "$START_DIR" | awk 'gsub("~", "'"$HOME"'", $0)')
    if [ -n "$TILDE_REPLACED" ]; then
        START_DIR="$TILDE_REPLACED"
    fi

    if [ ! -d "$START_DIR" ]; then
        echo "'$START_DIR' is not a directory"
        return 1
    fi

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
#   None
############################################################
install_hooks_into_repo() {
    TARGET="$1"
    if [ ! -w "${TARGET}/hooks" ]; then
        return
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
                mv "$TARGET_HOOK" "${TARGET_HOOK}.replaced.githook"
            fi
        fi

        if echo "$BASE_TEMPLATE_CONTENT" >"$TARGET_HOOK" && chmod +x "$TARGET_HOOK"; then
            INSTALLED="yes"
        else
            echo "Failed to install $TARGET_HOOK"
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
        printf "Looks like you already have shared hook repositories setup, do you want to change them now? [yN] "
    else
        echo "You can set up shared hook repositories to avoid duplicating common hooks across repositories you work on. See information on what are these in the project's documentation at https://github.com/rycus86/githooks#shared-hook-repositories"
        echo "Note: you can also have a .githooks/.shared file listing the repositories where you keep the shared hook files"
        printf "Would you like to set up shared hook repos now? [yN] "
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
        echo "Failed to set up the shared hook repositories!"
    fi
}

# Check if we're running in dry-run mode
DRY_RUN=$(is_dry_run "$@")

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

# Install the hooks into existing local repositories
if ! install_into_existing_repositories; then
    exit 1
fi

echo # For visual separation

# Set up shared hook repositories
setup_shared_hook_repositories

echo # For visual separation

echo "All done! Enjoy!

Please support the project by starring the project at https://github.com/rycus86/githooks, and report bugs or missing features or improvements as issues. Thanks!"
