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
    if [ -w "$TILDE_REPLACED" ]; then
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
    fi

    if [ ! -d "$START_DIR" ]; then
        echo "'$START_DIR' is not a directory" >&2
        return 1
    fi

    find "$START_DIR" \( -type d -and -name .git \) -or \
        \( -type f -and -name HEAD -and -not -path "*/.git/*" \) 2>/dev/null |
        while IFS= read -r EXISTING; do
            if [ -f "$EXISTING" ]; then
                # Strip HEAD file
                EXISTING=$(dirname "$EXISTING")
            fi
            uninstall_hooks_from_repo "$EXISTING"
        done

    return 0
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
    is_git_repo "$(pwd)" || exit 1
    [ -d "${CURRENT_GIT_DIR}" ] || return 1
}

############################################################
# Checks whether the given directory
#   is a Git repository (bare included) or not.
#
# Returns:
#   1 if failed, 0 otherwise
############################################################
is_git_repo() {
    (cd "$1" && git rev-parse >/dev/null 2>&1) || return 1
}

############################################################
# Uninstall the existing Git hook templates from the
#   current repository.
#
# Returns:
#   0 on success, 1 on failure
############################################################
uninstall_from_current_repository() {
    if ! is_running_in_git_repo_root; then
        echo "The current directory ($(pwd)) does not seem to be the root of a Git repository!" >&2
        exit 1
    fi

    uninstall_hooks_from_repo "$CURRENT_GIT_DIR"
}

############################################################
# Uninstall the existing Git hook templates from an existing
#   local repository, given by the first parameter.
#
# Returns:
#   None
############################################################
uninstall_hooks_from_repo() {
    TARGET="$1"

    if ! is_git_repo "${TARGET}"; then
        return
    fi

    if [ ! -w "${TARGET}/hooks" ]; then
        return
    fi

    UNINSTALLED="no"

    for TARGET_HOOK in "$TARGET"/hooks/*; do
        if [ -f "$TARGET_HOOK" ]; then
            grep 'https://github.com/rycus86/githooks' "${TARGET_HOOK}" >/dev/null 2>&1

            # shellcheck disable=SC2181
            if [ $? -eq 0 ]; then
                rm -f "$TARGET_HOOK"
                UNINSTALLED="yes"

                # Restore the previously moved hook if there was any
                if [ -f "${TARGET_HOOK}.replaced.githook" ]; then
                    mv "${TARGET_HOOK}.replaced.githook" "$TARGET_HOOK"
                fi
            fi
        fi
    done

    if [ -f "${TARGET}/.githooks.checksum" ]; then
        rm -f "${TARGET}/.githooks.checksum"
        UNINSTALLED="yes"
    fi

    if [ "$UNINSTALLED" = "yes" ]; then
        echo "Hooks are uninstalled from $TARGET"
    fi

    # If Git LFS is available, try installing the LFS hooks again
    if [ "$GIT_LFS_AVAILABLE" = "true" ]; then
        OUTPUT=$(cd "$TARGET_DIR" && git lfs install 2>&1)
        #shellcheck disable=2181
        if [ $? -ne 0 ]; then
            echo "! Reinstalling Git LFS in \`$TARGET_DIR\` failed! Output:" >&2
            echo "$OUTPUT" >&2
        fi
    fi
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
    if [ "$USE_HOOKS_PATH" = "yes" ]; then
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
        if ! rm -rf "${INSTALL_DIR:?}/shared" >/dev/null 2>&1; then
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
    if [ -d "$INSTALL_DIR/bin" ]; then
        if ! rm -rf "${INSTALL_DIR:?}/bin" >/dev/null 2>&1; then
            echo "! Failed to delete the githook command-line tool" >&2
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
# Sets the ${CURRENT_GIT_DIR} variable
# Sets the ${INSTALL_DIR} variable
# Sets the ${GIT_LFS_AVAILABLE} variable
#
# Returns: None
#####################################################
set_main_variables() {
    CURRENT_GIT_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
    if [ "${CURRENT_GIT_DIR}" = "--git-common-dir" ]; then
        CURRENT_GIT_DIR=".git"
    fi

    load_install_dir || return 1

    # do we have Git LFS installed
    GIT_LFS_AVAILABLE="false"
    command -v git-lfs >/dev/null 2>&1 && GIT_LFS_AVAILABLE="true"

    return 0
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

    # Unset global Githooks variables
    git config --global --unset githooks.shared
    git config --global --unset githooks.failOnNonExistingSharedHooks
    git config --global --unset githooks.autoupdate.enabled
    git config --global --unset githooks.autoupdate.lastrun
    git config --global --unset githooks.previous.searchdir
    git config --global --unset githooks.disable
    git config --global --unset githooks.installDir
    git config --global --unset alias.hooks

    if using_hooks_path; then
        git config --global --unset githooks.useCoreHooksPath

        GITHOOKS_CORE_HOOKSPATH=$(git config --global githooks.pathForUseCoreHooksPath)
        GIT_CORE_HOOKSPATH=$(git config --global core.hooksPath)

        if [ "$GITHOOKS_CORE_HOOKSPATH" = "$GIT_CORE_HOOKSPATH" ]; then
            git config --global --unset core.hooksPath
        fi

        git config --global --unset githooks.pathForUseCoreHooksPath
    fi

    # Finished
    echo "All done!"
    echo
    echo "If you ever want to reinstall the hooks, just follow"
    echo "the install instructions at https://github.com/rycus86/githooks"

    return 0
}

uninstall "$@" || exit 1
