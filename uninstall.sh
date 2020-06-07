#!/bin/sh
#
# Uninstalls the base Git hook templates from https://github.com/rycus86/githooks
#   See the documentation in the project README for more information.

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

    # 2. from git config for templateDir
    mark_directory_as_target "$(git config --get init.templateDir)" "hooks"
    if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi

    # 3. from git config for hooksPath
    mark_directory_as_target "$(git config --get core.hooksPath)"
    if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi

    # 4. from the default location
    mark_directory_as_target "/usr/share/git-core/templates/hooks"
    if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi
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
# Uninstall the existing Git hook templates from the
#   Git template directory.
#
# Returns:
#   None
############################################################
remove_existing_hook_templates() {
    for TEMPLATE_FILE in "$1"/*; do
        grep 'https://github.com/rycus86/githooks' "${TEMPLATE_FILE}" >/dev/null 2>&1

        # shellcheck disable=SC2181
        if [ $? -eq 0 ]; then
            rm -f "$TEMPLATE_FILE"
            echo "Removed hook template at $TEMPLATE_FILE"

            # Restore the previously moved hook if there was any
            if [ -f "${TEMPLATE_FILE}.replaced.githook" ]; then
                mv "${TEMPLATE_FILE}.replaced.githook" "$TEMPLATE_FILE"
            fi
        fi
    done
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
# Uninstall the existing Git hook templates from the
#   existing local repositories.
#
# Returns:
#   0 on success, 1 on failure
############################################################
uninstall_from_existing_repositories() {
    # Don't offer to remove from repo's if we were using the hooksPath implementation
    if using_hooks_path; then
        return 0
    fi

    printf 'Do you want to uninstall the hooks from existing repositories? [yN] '
    read -r DO_UNINSTALL
    if [ "$DO_UNINSTALL" != "y" ] && [ "$DO_UNINSTALL" != "Y" ]; then return 0; fi

    PRE_START_DIR=$(git config --global --get githooks.previous.searchdir)
    # shellcheck disable=SC2181
    if [ $? -eq 0 ] && [ -n "$PRE_START_DIR" ]; then
        START_DIR="$PRE_START_DIR"
    else
        START_DIR=~
    fi

    printf 'Where do you want to start the search? [%s] ' "$START_DIR"
    read -r START_DIR

    if [ "$START_DIR" = "" ]; then
        START_DIR="$HOME"
    else
        TILDE_REPLACED=$(echo "$START_DIR" | awk 'gsub("~", "'"$HOME"'", $0)')
        if [ -n "$TILDE_REPLACED" ]; then
            START_DIR="$TILDE_REPLACED"
        fi
    fi

    if [ ! -d "$START_DIR" ]; then
        echo "'$START_DIR' is not a directory" >&2
        return 1
    fi

    find_existing_git_dirs "$START_DIR"

    # Loop over all existing git dirs
    IFS="$IFS_NEWLINE"
    for EXISTING in $EXISTING_REPOSITORY_LIST; do
        unset IFS

        uninstall_hooks_from_repo "$EXISTING"

        IFS="$IFS_NEWLINE"
    done
    unset IFS

    return 0
}

#####################################################
# Uninstall from all repositories in
#   `autoupdate.registered` which gets deleted
#    at the end.
#
# Returns: 0
#####################################################
uninstall_from_registered_repositories() {

    LIST="$INSTALL_DIR/autoupdate/registered"
    if [ -f "$LIST" ]; then

        # Filter list according to
        # - non-existing repos
        # - if marked as single install.

        # Uninstall list
        UNINSTALL_LIST=$(mktemp)

        IFS="$IFS_NEWLINE"
        while read -r INSTALLED_REPO; do
            unset IFS

            if [ "$(git -C "$INSTALLED_REPO" rev-parse --is-inside-git-dir)" = "false" ]; then
                # Not existing git dir -> skip.
                true

            elif (cd "$INSTALLED_REPO" && [ "$(git config --local githooks.single.install)" = "yes" ]); then
                # Found a registered repo which is now a single install:
                # -> remove registered flag and skip.
                git -C "$INSTALLED_REPO" config --local --unset githooks.autoupdate.registered >/dev/null 2>&1

            else
                # Found existing registed repository -> uninstall
                echo "$INSTALLED_REPO" >>"$UNINSTALL_LIST"
            fi

            IFS="$IFS_NEWLINE"
        done <"$LIST"

        if [ -s "$UNINSTALL_LIST" ]; then
            echo "The following registered repositories in \`$LIST\`"
            echo "contain a Githooks installation:"
            sed -E "s/^/ - /" <"$UNINSTALL_LIST"
            printf 'Do you want to uninstall from all of them? [Yn] '

            read -r DO_UNINSTALL
            if [ "$DO_UNINSTALL" = "n" ] || [ "$DO_UNINSTALL" = "N" ]; then
                rm -f "$UNINSTALL_LIST" >/dev/null 2>&1
                # Do not change registered list.
                return 0
            fi

            # Loop over all existing git dirs
            IFS="$IFS_NEWLINE"
            while read -r INSTALLED_REPO; do
                unset IFS
                uninstall_hooks_from_repo "$INSTALLED_REPO"
                IFS="$IFS_NEWLINE"
            done <"$UNINSTALL_LIST"
            rm -f "$UNINSTALL_LIST" >/dev/null 2>&1
        fi

        # Remove the registered list since we
        # uninstalled from all registered repos.
        rm -f "$LIST" >/dev/null 2>&1
    fi

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
# Removes the repository from the list `autoupdate.registered`
#  for potential future autoupdates.
#
# Returns: None
############################################################
unregister_repo() {
    CURRENT_REPO="$(cd "$1" && pwd)"
    LIST="$INSTALL_DIR/autoupdate/registered"

    # Remove
    if [ -f "$LIST" ]; then
        TEMP_FILE=$(mktemp)
        CURRENT_ESCAPED=$(echo "$CURRENT_REPO" | sed "s@/@\\\\\/@g")
        sed "/$CURRENT_ESCAPED/d" "$LIST" >"$TEMP_FILE"
        mv -f "$TEMP_FILE" "$LIST"
    fi
}

############################################################
# Uninstall the existing Git hook templates from the
#   current repository.
#
# Returns:
#   0 on success, 1 on failure
############################################################
uninstall_from_current_repository() {
    if ! is_git_repo "$(pwd)"; then
        echo "! The current directory ($(pwd)) does not seem to be inside a Git repository!" >&2
        exit 1
    fi

    REPO_GIT_DIR=$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd)
    uninstall_hooks_from_repo "$REPO_GIT_DIR"
}

############################################################
# Uninstall the existing Git hook templates from an existing
#   local repository, given by the first parameter.
#
# Returns:
#   0 if sucessful, 1 otherwise
############################################################
uninstall_hooks_from_repo() {
    TARGET="$1"

    if [ ! -w "${TARGET}/hooks" ]; then
        echo "! Could not uninstall from \`$TARGET\` because there is no write access."
        return 1
    fi
    UNINSTALLED="false"

    for TARGET_HOOK in "$TARGET/hooks/"*; do
        if [ -f "$TARGET_HOOK" ]; then
            grep 'https://github.com/rycus86/githooks' "${TARGET_HOOK}" >/dev/null 2>&1

            # shellcheck disable=SC2181
            if [ $? -eq 0 ]; then
                rm -f "$TARGET_HOOK"
                UNINSTALLED="true"

                # Restore the previously moved hook if there was any
                if [ -f "${TARGET_HOOK}.replaced.githook" ]; then
                    mv "${TARGET_HOOK}.replaced.githook" "$TARGET_HOOK"
                fi
            fi
        fi
    done

    if [ -f "${TARGET}/.githooks.checksum" ]; then
        rm -f "${TARGET}/.githooks.checksum"
        UNINSTALLED="true"
    fi

    # Remove all install relevant local githooks configs
    (
        cd "${TARGET}" &&
            git config --local --unset githooks.single.install >/dev/null &&
            git config --local --unset githooks.autoupdate.registered >/dev/null 2>&1
    )

    if [ "$UNINSTALLED" = "true" ]; then
        echo "Hooks are uninstalled from $TARGET"
    fi

    # Always remove this repo from the registered list (also single install)
    unregister_repo "${TARGET}"

    # If Git LFS is available, try installing the LFS hooks again
    if [ "$GIT_LFS_AVAILABLE" = "true" ]; then
        OUTPUT=$(git -C "$TARGET" lfs install 2>&1)
        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo "! Reinstalling Git LFS in \`$TARGET\` failed! Output:" >&2
            echo "$OUTPUT" >&2
        fi
    fi

    return 0
}

############################################################
# Checks if we're using the hooksPath
#   or templateDir implementation.
#
# Returns:
#   0 on true, 1 on false
############################################################
using_hooks_path() {
    USE_HOOKS_PATH=$(git config --global githooks.useCoreHooksPath)
    if [ "$USE_HOOKS_PATH" = "true" ] ||
        [ "$USE_HOOKS_PATH" = "yes" ]; then # Legacy
        return 0
    else
        return 1
    fi
}

# Uninstall shared hooks.
#
# Returns:
#   None
############################################################
uninstall_shared_hooks() {
    if [ -d "$INSTALL_DIR/shared" ]; then
        if ! rm -rf "${INSTALL_DIR}/shared" >/dev/null 2>&1; then
            echo "! Failed to delete shared hook repository folders" >&2
            exit 1
        fi
    fi
}

############################################################
# Uninstall the cli tool.
#
# Returns:
#   None
############################################################
uninstall_cli() {
    # This is legacy for old installs
    # the cli tool does not get installed anymore
    # but used directly from the release clone
    CLI_DIR="${INSTALL_DIR}/bin"
    if [ -d "$CLI_DIR" ]; then
        if ! rm -rf "$CLI_DIR" >/dev/null 2>&1; then
            echo "! Failed to delete the githooks command-line tool" >&2
            exit 1
        fi
    fi
}

############################################################
# Uninstall the release repository.
#
# Returns:
#   None
############################################################
uninstall_release_repo() {
    RELEASE_DIR="${INSTALL_DIR}/release"
    if [ -d "$RELEASE_DIR" ]; then
        if ! rm -rf "$RELEASE_DIR" >/dev/null 2>&1; then
            echo "! Failed to delete the githooks release repository" >&2
            exit 1
        fi
    fi
}

#####################################################
# Sets the ${INSTALL_DIR} variable
#
# Returns:
#   0 if success, 1 otherwise
#####################################################
load_install_dir() {
    INSTALL_DIR=$(git config --global --get githooks.installDir)

    if [ -z "$INSTALL_DIR" ]; then
        # install dir not defined, use default
        INSTALL_DIR=~/".githooks"
    elif [ ! -d "$INSTALL_DIR" ]; then
        echo "! Githooks installation is corrupt! " >&2
        echo "  Install directory at ${INSTALL_DIR} is missing." >&2
        INSTALL_DIR=~/".githooks"
        echo "  Using default install directory at $INSTALL_DIR" >&2
    fi

    # Final check since we are going to delete folders
    if ! echo "$INSTALL_DIR" | grep -q ".githooks"; then
        echo "! Uninstall path at $INSTALL_DIR needs to contain \`.githooks\`" >&2
        return 1
    fi

    return 0
}

#####################################################
# Check the install is local or global
#
# Returns: 0 if uninstall is local, 1 otherwise
#####################################################
is_local_uninstall() {
    [ "$UNINSTALL_LOCAL" = "true" ] || return 1
}

#####################################################
# Parse command line args.
#
# Returns: None
#####################################################
parse_command_line_args() {
    # Global or local uninstall
    if [ "$1" = "--local" ]; then
        UNINSTALL_LOCAL="true"
    else
        UNINSTALL_LOCAL="false"
    fi
}

#####################################################
# Set up the main variables that
#   we will throughout the hook.
#
# Sets the ${INSTALL_DIR} variable
# Sets the ${GIT_LFS_AVAILABLE} variable
#
# Returns: None
#####################################################
set_main_variables() {

    IFS_NEWLINE="
"
    load_install_dir || return 1

    # do we have Git LFS installed
    GIT_LFS_AVAILABLE="false"
    command -v git-lfs >/dev/null 2>&1 && GIT_LFS_AVAILABLE="true"

    return 0
}

#####################################################
# Try removing core.hooksPath if we are using it.

# Returns: 0 if success, 1 otherwise
#####################################################
remove_core_hooks_path() {
    if using_hooks_path; then
        GITHOOKS_CORE_HOOKSPATH=$(git config --global githooks.pathForUseCoreHooksPath)
        GIT_CORE_HOOKSPATH=$(git config --global core.hooksPath)

        if [ "$GITHOOKS_CORE_HOOKSPATH" = "$GIT_CORE_HOOKSPATH" ]; then
            git config --global --unset core.hooksPath
        fi
    fi
}

#####################################################
# Main uninstall routine.

# Returns: 0 if success, 1 otherwise
#####################################################
uninstall() {
    set_main_variables || return 1
    parse_command_line_args "$@"

    if [ "$UNINSTALL_LOCAL" = "true" ]; then
        # Uninstall the hooks from the current repository
        if uninstall_from_current_repository; then
            return 0
        else
            echo "! Failed to uninstall from current repository" >&2
            return 1
        fi
    fi

    # Uninstall the hooks from existing local repositories
    if ! uninstall_from_existing_repositories; then
        echo "! Failed to uninstall from existing repositories" >&2
        return 1
    fi

    if ! uninstall_from_registered_repositories; then
        echo "! Failed to uninstall from registered repositories" >&2
        return 1
    fi

    # Find the current Git hook templates directory
    TARGET_TEMPLATE_DIR=""

    find_git_hook_templates

    if [ ! -d "$TARGET_TEMPLATE_DIR" ]; then
        echo "Git hook templates directory not found" >&2
        return 1
    fi

    # Delete the hook templates
    remove_existing_hook_templates "$TARGET_TEMPLATE_DIR"

    # Uninstall all shared hooks
    uninstall_shared_hooks

    # Uninstall all cli
    uninstall_cli

    # uninstall release repo
    uninstall_release_repo

    # remove core hooks path if we are using it
    remove_core_hooks_path

    # Unset global Githooks variables
    git config --global --unset githooks.shared
    git config --global --unset githooks.failOnNonExistingSharedHooks
    git config --global --unset githooks.maintainOnlyServerHooks
    git config --global --unset githooks.autoupdate.enabled
    git config --global --unset githooks.autoupdate.lastrun
    git config --global --unset githooks.autoupdate.updateCloneUrl
    git config --global --unset githooks.autoupdate.updateCloneBranch
    git config --global --unset githooks.previous.searchdir
    git config --global --unset githooks.disable
    git config --global --unset githooks.installDir
    git config --global --unset githooks.deleteDetectedLFSHooks
    git config --global --unset githooks.pathForUseCoreHooksPath
    git config --global --unset githooks.useCoreHooksPath
    git config --global --unset alias.hooks

    # Finished
    echo "All done!"
    echo
    echo "If you ever want to reinstall the hooks, just follow"
    echo "the install instructions at https://github.com/rycus86/githooks"

    return 0
}

uninstall "$@" || exit 1
