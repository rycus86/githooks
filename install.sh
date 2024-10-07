#!/bin/sh
#
# Installs the base Git hook templates from https://github.com/rycus86/githooks
#   and performs some optional setup for existing repositories.
#   See the documentation in the project README for more information.
#
# Legacy version number. Not used anymore, but old installs read it.
# Version: 9912.310000-000000

# The list of hooks we can manage with this script
MANAGED_HOOK_NAMES="
    applypatch-msg pre-applypatch post-applypatch
    pre-commit pre-merge-commit prepare-commit-msg commit-msg post-commit
    pre-rebase post-checkout post-merge pre-push
    pre-receive update post-receive post-update reference-transaction
    push-to-checkout pre-auto-gc post-rewrite sendemail-validate
    post-index-change
"

MANAGED_SERVER_HOOK_NAMES="
    pre-push pre-receive update post-receive post-update
    reference-transaction push-to-checkout pre-auto-gc
"

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
    parse_command_line_arguments "$@" || return 1

    load_install_dir || return 1

    if ! is_postupdate; then

        check_deprecation || return 1

        legacy_transform_before_update || return 1

        update_release_clone || return 1

        if is_clone_updated || ! is_running_internal_install; then
            # Either
            # - we just updated the release clone -> dispatch to the new install
            # - or we are running not from the release clone -> dispatch to the install
            # in the clone.
            run_internal_install --internal-postupdate "$@" || return 1
            return 0
        fi
    fi

    # From here starts the post update logic
    # meaning the `--internal-postupdate` flag is set
    # and we are running inside the release clone
    # meaning the `--internal-install` flag is set.

    if ! is_dry_run; then
        legacy_transform_after_update || return 1
    fi

    if is_non_interactive; then
        disable_tty_input
    fi

    # Find the directory to install to
    if is_single_repo_install; then
        get_cwd_git_dir || return 1
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
    if ! is_autoupdate && setup_automatic_update_checks; then
        echo # For visual separation
    fi

    if ! should_skip_install_into_existing_repositories; then
        if is_single_repo_install; then
            get_cwd_git_dir || return 1
            install_hooks_into_repo "$CWD_GIT_DIR" || return 1
        else
            if ! is_autoupdate; then
                install_into_existing_repositories
            fi
            install_into_registered_repositories
        fi
    fi

    echo # For visual separation

    # Set up shared hook repositories if needed
    if ! is_autoupdate && ! is_non_interactive && ! is_single_repo_install; then
        setup_shared_hook_repositories
        echo # For visual separation
    fi

    # Legacy transformations
    if ! is_dry_run && ! is_single_repo_install; then
        legacy_transform_end || return 1
    fi

    thank_you

    return 0
}

############################################################
# Checks if any deprecated features are used
#
# Returns:
#   1 if the install should be aborted, 0 otherwise
############################################################
check_deprecation() {
    if is_single_repo_install || is_autoupdate; then
        if ! check_not_deprecated_single_install; then
            echo "! Install failed due to deprecated single install" >&2
            return 1
        fi
    fi
    return 0
}

############################################################
# Function to dispatch to all legacy transformations
#   at the start.
#   We are not yet deleting  old values since the install
#   could go wrong and dry-run could also be activated.
#
# Returns: 0 if successful, 1 otherwise
############################################################
legacy_transform_before_update() {

    LEGACY_TRANSFORM_FAILURES="false"

    # Variable transformations in global git config
    # Can be applied to all versions without any problem
    OLD_CONFIG_VALUE=$(git config --global githooks.autoupdate.updateCloneUrl)
    if [ -n "$OLD_CONFIG_VALUE" ]; then
        git config --global githooks.cloneUrl "$OLD_CONFIG_VALUE" || LEGACY_TRANSFORM_FAILURES="true"
    fi

    OLD_CONFIG_VALUE=$(git config --global githooks.autoupdate.updateCloneBranch)
    if [ -n "$OLD_CONFIG_VALUE" ]; then
        git config --global githooks.cloneBranch "$OLD_CONFIG_VALUE" || LEGACY_TRANSFORM_FAILURES="true"
    fi

    OLD_CONFIG_VALUE=$(git config --global githooks.previous.searchdir)
    if [ -n "$OLD_CONFIG_VALUE" ]; then
        git config --global githooks.previousSearchDir "$OLD_CONFIG_VALUE" || LEGACY_TRANSFORM_FAILURES="true"
    fi

    # Copy legacy file to new location
    if [ -f "$INSTALL_DIR/autoupdate/registered" ]; then
        cp "$INSTALL_DIR/autoupdate/registered" "$INSTALL_DIR/registered" || LEGACY_TRANSFORM_FAILURES="true"
    fi

    if [ "$LEGACY_TRANSFORM_FAILURES" = "true" ]; then
        echo "! There were legacy transform errors: check stderr"
        return 1
    fi

    return 0
}

############################################################
# Tests if the commit sha `$1`
#   is before or equal of the commit sha `$2`.
#
# Returns: 0 if successful, 1 otherwise
############################################################
legacy_transform_is_ancestor() {
    if [ -n "$1" ] && [ -n "$2" ] &&
        execute_git "$GITHOOKS_CLONE_DIR" merge-base --is-ancestor \
            "$1" "$2" >/dev/null 2>&1; then
        # commit 1 <= commit 2
        return 0
    fi

    return 1
}

############################################################
# Function to dispatch to all legacy transformations
#   right after the update.
#
# Returns: 0 if successful, 1 otherwise
############################################################
legacy_transform_after_update() {
    COMMIT_COUNT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-list --count HEAD)
    GITHOOKS_CLONE_CURRENT_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse HEAD)

    if [ "$COMMIT_COUNT" != "1" ] && [ -z "${INTERNAL_UPDATED_FROM_COMMIT+set}" ]; then
        # If the clone dir has been updated (commit count != 1) and
        # we do not have the update commit yet (meaning we are updating from an old version )
        # we set it to the last commit where this feature (INTERNAL_UPDATED_FROM_COMMIT)
        # was not yet available
        INTERNAL_UPDATED_FROM_COMMIT="ab86d2a529f58744a71e79227e434f19b84589e6"
    fi

    # Because of changes in PR #125 right after commit ab86d2a5:
    # - Check if we need transforms for `--global githooks.shared`
    #   to be split into multiple config values
    # - Show info that all hook hashes are differently computed now
    #   and every hooks needs to be trusted again.
    # - Show info that `githooks.failOnNonExistingHooks` is enabled due to renaming
    #   internal cloned shared hooks repositories.
    if legacy_transform_is_ancestor \
        "$INTERNAL_UPDATED_FROM_COMMIT" \
        "ab86d2a529f58744a71e79227e434f19b84589e6"; then

        legacy_transform_split_global_shared_entries || LEGACY_TRANSFORM_FAILURES="true"

        echo >&2
        echo "! Info: Because the hash algorithm changed from" >&2
        echo "  \$(md5sum) to \$(git hash-object)," >&2
        echo "  you unfortunately need to retrust all hooks again." >&2
        echo >&2
    fi

}

############################################################
# Function to dispatch to all legacy transformations
#   at the end
#
# Returns: 0
############################################################
legacy_transform_end() {

    # Variable transformations in global git config
    # Can be applied to all versions without any problem
    git config --global --unset githooks.autoupdate.updateCloneUrl
    git config --global --unset githooks.autoupdate.updateCloneBranch
    git config --global --unset githooks.previous.searchdir

    # Remove legacy registration file (we moved it to another location)
    if [ -f "$INSTALL_DIR/autoupdate/registered" ]; then
        rm -rf "$INSTALL_DIR/autoupdate" || LEGACY_TRANSFORM_FAILURES="true"
    fi

    legacy_transform_registered_repos || LEGACY_TRANSFORM_FAILURES="true"

    if [ "$LEGACY_TRANSFORM_FAILURES" = "true" ]; then
        echo "! There were legacy transform errors: check stderr"
        return 1
    fi

    return 0
}

############################################################
# Transform all comma-delimited global \`githooks.shared\`
#   values into multiple git config values.
#
# Returns:
#   1 when failed, 0 otherwise
############################################################
legacy_transform_split_global_shared_entries() {

    CURRENT_LIST=$(git config --global --get githooks.shared)

    FAILURE="false"

    # If it contains a comma, split it...
    if echo "$CURRENT_LIST" | grep -q ","; then

        git config --global --unset githooks.shared

        # Split it and add all back
        IFS=",$IFS_NEWLINE"
        for ITEM in $CURRENT_LIST; do
            unset IFS

            if [ -n "$ITEM" ]; then
                git config --global --add githooks.shared "$ITEM" || FAILURE="true"
            fi

            IFS=",$IFS_NEWLINE"
        done
        unset IFS
    fi

    if [ "$FAILURE" = "true" ]; then
        echo "! Warning: Could not migrate the global shared hook repositories setting:" >&2
        echo "\`$CURRENT_LIST\`" >&2
        echo " Please check \`githooks.shared\` and add all comma-separated" >&2
        echo " values manually by running:" >&2
        echo "  \$ git config --global --add githooks.shared <value>" >&2
        LEGACY_TRANSFORM_FAILURES="true"
    fi

    return 0
}

############################################################
# Function to dispatch to all legacy transformations
#   for all registered repos.
#
# Returns:
#   1 when failed, 0 otherwise
############################################################
legacy_transform_registered_repos() {

    # Check if we need transforms for `.shared` files:
    # Put local paths into `--local githooks.shared`.
    # which was introduced by PR #125 right after commit ab86d2a5:
    PR_125="false"
    if legacy_transform_is_ancestor \
        "$INTERNAL_UPDATED_FROM_COMMIT" \
        "ab86d2a529f58744a71e79227e434f19b84589e6"; then
        PR_125="true"
    fi

    if [ "$(git config --global githooks.useCoreHooksPath)" = "true" ]; then
        if [ "$PR_125" = "true" ]; then
            echo >&2
            echo "! DEPRECATION WARNING: Local paths for shared hook repositories" >&2
            echo "  configured with \`.githooks/.shared\` files per repository" >&2
            echo "  are no more supported and need" >&2
            echo "  to be moved manually to the local Git configuration variable" >&2
            echo "  \`githooks.shared\` by running:" >&2
            echo "    \$ git hooks shared add --local <local path>" >&2
            echo >&2

            echo >&2
            echo "! DEPRECATION WARNING: Because of renaming of internal cloned shared" >&2
            echo "  hook repositories, you should update all shared hook repositories" >&2
            echo "  by running in all repositories using Githooks:" >&2
            echo "    \$ git hooks shared update" >&2
            echo "  The Git config variable \`githooks.failOnNonExistingSharedHooks\` has been" >&2
            echo "  enabled globally to safely fail if you forgot to update them." >&2
            echo >&2
            git config --global githooks.failOnNonExistingSharedHooks "true"

        fi
    else

        LIST="$INSTALL_DIR/registered"
        if [ ! -f "$LIST" ]; then
            return 0
        fi
        IFS="$IFS_NEWLINE"
        while read -r REGISTERED_REPO; do
            unset IFS

            if [ "$(git -C "$REGISTERED_REPO" rev-parse --is-inside-git-dir 2>/dev/null)" != "true" ]; then
                # Not existing git dir -> skip.
                true
            else
                WORKTREES=$(get_repo_worktrees "$REGISTERED_REPO")

                IFS="$IFS_NEWLINE"
                for TREE in $WORKTREES; do
                    unset IFS

                    # safe guard: a bit buggy get_repo_worktrees
                    if [ "$(git -C "$TREE" rev-parse --is-inside-git-dir 2>/dev/null)" = "true" ]; then
                        continue
                    fi

                    legacy_transform_remove_legacy_config "$TREE"

                    if [ "$PR_125" = "true" ]; then

                        legacy_transform_adjust_local_paths "$TREE" ||
                            LEGACY_TRANSFORM_FAILURES="true"

                        legacy_transform_update_shared_hooks "$TREE" ||
                            LEGACY_TRANSFORM_FAILURES="true"
                    fi

                    IFS="$IFS_NEWLINE"
                done
            fi

            IFS="$IFS_NEWLINE"
        done <"$LIST"
    fi

    return 0
}

############################################################
# Remove legacy config values in repo `$1`.
#
# Returns: None
############################################################
legacy_transform_remove_legacy_config() {
    git -C "$REGISTERED_REPO" config --local --unset githooks.autoupdate.registered >/dev/null 2>&1
}

############################################################
# Function to adjust local paths in `.githooks/.shared`
#   file which are forbidden.
#
# Returns:
#   1 when failed, 0 otherwise
############################################################
legacy_transform_adjust_local_paths() {

    SHARED_FILE="$1/.githooks/.shared"

    if [ -f "$SHARED_FILE" ]; then

        NEW_SHARED_LIST=$(mktemp)
        MOVED_URLS=$(mktemp)

        MOVED="false"
        IFS=",$IFS_NEWLINE" # legacy split also with comma -> put it on a new line
        while read -r LINE || [ -n "$LINE" ]; do
            unset IFS

            if echo "$LINE" | grep -qE "^\s*(#.*)?$"; then

                echo "$LINE" >>"$NEW_SHARED_LIST"

            elif is_local_path "$LINE" || is_local_url "$LINE"; then
                git -C "$1" config --local --add githooks.shared "$LINE"

                echo "$LINE" >>"$MOVED_URLS"
                MOVED="true"
            else
                echo "$LINE" >>"$NEW_SHARED_LIST"
            fi

            IFS=",$IFS_NEWLINE"
        done <"$SHARED_FILE"

        cp -f "$NEW_SHARED_LIST" "$SHARED_FILE" &&
            rm -rf "$NEW_SHARED_LIST" >/dev/null 2>&1

        if [ "$MOVED" = "true" ]; then

            echo "! Warning: The shared hooks configuration in" >&2
            echo "  \`$SHARED_FILE\`" >&2
            echo "  contains local paths which are not supported" >&2
            echo "  any more:" >&2
            sed -E "s/^/   - /" "$MOVED_URLS" >&2
            echo "  These paths are now moved to the local Git" >&2
            echo "  configuration value \`githooks.shared\`." >&2
            echo "  The file \`$SHARED_FILE\` has been changed and" >&2
            echo "  should be committed!" >&2
        fi

        rm -rf "$MOVED_URLS" >/dev/null 2>&1

    fi

    return 0
}

############################################################
# Function to update shared hooks repos in configured by
#   `.shared` file in repo `$1`.
#
# Returns:
#   1 when failed, 0 otherwise
############################################################
legacy_transform_update_shared_hooks() {
    # Could be more efficient if we have a "--shared,--local,--global"
    # flag on this command.
    if [ -d "$1" ]; then
        out=$(cd "$1" 2>&1 && sh "$GITHOOKS_CLONE_DIR/cli.sh" shared update 2>&1)
        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo "! Could not execute shared update in" >&2
            echo "  \`$1\`" >&2
            echo "  Errors: \`$out\`" >&2
            return 1
        fi
    fi
    return 0
}

#####################################################
# Check if `$1` is not a supported git clone url and
#   is treated as a local path to a repository.
#   See `https://tools.ietf.org/html/rfc3986#appendix-B`

# Returns: 0 if it is a local path, 1 otherwise
#####################################################
is_local_path() {
    if echo "$1" | grep -Eq "^[^:/?#]+://" ||  # it is a <scheme>://
        echo "$1" | grep -Eq "^.+@.+:.+"; then # or it is a short scp syntax
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

    GITHOOKS_CLONE_DIR="$INSTALL_DIR/release"

    if is_dry_run; then
        return 0
    fi

    if ! git config --global githooks.installDir "$INSTALL_DIR"; then
        echo "! Could not set \`githooks.installDir\`"
        return 1
    fi

    if ! git config --global githooks.runner "$INSTALL_DIR/release/base-template.sh"; then
        echo "! Could not set \`githooks.runner\`"
        return 1
    fi

    return 0
}

############################################################
# Checks if we are running an internal install
#  from the release repository.
#
# Returns: 0 if `true`, 1 otherwise
############################################################
is_running_internal_install() {
    if [ "$INTERNAL_INSTALL" = "true" ] ||
        [ "$INTERNAL_INSTALL" = "yes" ]; then # Legacy over environment
        return 0
    fi
    return 1
}

############################################################
# Set up variables based on command line arguments.
#
# Returns: 0 if all arguments are parsed correctly, 1 otherwise
############################################################
parse_command_line_arguments() {
    TARGET_TEMPLATE_DIR=""
    for p in "$@"; do
        if [ "$p" = "--internal-autoupdate" ]; then
            INTERNAL_AUTOUPDATE="true"
        elif [ "$p" = "--internal-install" ]; then
            INTERNAL_INSTALL="true"
        elif [ "$p" = "--internal-postupdate" ]; then
            INTERNAL_POSTUPDATE="true"
        elif [ "$p" = "--internal-updated-from" ]; then
            : # nothing to do here
        elif [ "$prev_p" = "--internal-updated-from" ] && (echo "$p" | grep -qvE '^\-\-.*'); then
            INTERNAL_UPDATED_FROM_COMMIT="$p"
        elif [ "$p" = "--dry-run" ]; then
            DRY_RUN="true"
        elif [ "$p" = "--non-interactive" ]; then
            NON_INTERACTIVE="true"
        elif [ "$p" = "--single" ]; then
            SINGLE_REPO_INSTALL="true"
        elif [ "$p" = "--skip-install-into-existing" ]; then
            SKIP_INSTALL_INTO_EXISTING="true"
        elif [ "$p" = "--prefix" ]; then
            : # nothing to do here
        elif [ "$prev_p" = "--prefix" ] && (echo "$p" | grep -qvE '^\-\-.*'); then
            # Allow user to pass preferred install prefix
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
            # Allow user to pass preferred template dir
            TARGET_TEMPLATE_DIR="$p"
        elif [ "$p" = "--only-server-hooks" ]; then
            INSTALL_ONLY_SERVER_HOOKS="true"
        elif [ "$p" = "--use-core-hookspath" ]; then
            USE_CORE_HOOKSPATH="true"
            # No point in installing into existing when using core.hooksPath
            SKIP_INSTALL_INTO_EXISTING="true"
        elif [ "$p" = "--clone-url" ]; then
            : # nothing to do here
        elif [ "$prev_p" = "--clone-url" ] && (echo "$p" | grep -qvE '^\-\-.*'); then
            GITHOOKS_CLONE_URL="$p"
        elif [ "$p" = "--clone-branch" ]; then
            : # nothing to do here
        elif [ "$prev_p" = "--clone-branch" ] && (echo "$p" | grep -qvE '^\-\-.*'); then
            GITHOOKS_CLONE_BRANCH="$p"
        else
            echo "! Unknown argument \`$p\`" >&2
            return 1
        fi
        prev_p="$p"
    done

    # Legacy flag over environment
    if [ "$DO_UPDATE_ONLY" = "yes" ]; then
        unset DO_UPDATE_ONLY
        INTERNAL_AUTOUPDATE="true"
    fi

    # Using core.hooksPath implies it applies to all repo's
    if is_single_repo_install && use_core_hookspath; then
        echo "! Cannot use --single and --use-core-hookspath together" >&2
        return 1
    fi
}

############################################################
# Check if this repo is not a deprecated single install.
#
# Returns: 1 if deprecated single install, 0 otherwise
############################################################
check_not_deprecated_single_install() {
    if is_git_repo "$(pwd)" && git config --local githooks.single.install >/dev/null 2>&1; then
        echo >&2
        echo "! DEPRECATION WARNING: Single install repositories are" >&2
        echo "  deprecated!" >&2
        echo >&2
        echo "  The single installation feature" >&2
        echo "  with \`--single\` was changed to the following only" >&2
        echo "  behavior:" >&2
        echo "" >&2
        echo "    - install Githooks hooks into the current repository" >&2
        echo "    - the installed hooks are not standalone anymore" >&2
        echo "      and behave exactly the same as current non-single" >&2
        echo "      installs" >&2
        echo >&2
        echo "    You appear to have setup this repo as a single install." >&2
        echo "    The hooks in this repository are not supported anymore." >&2
        echo >&2
        echo "    To install the latest hooks you need to reset this option" >&2
        echo "    by running" >&2
        echo "      \`git config --local --unset githooks.single.install\`" >&2
        echo "    in order to use this repository with githooks." >&2
        echo >&2
        return 1 # DeprecateSingleInstall
    fi
    return 0
}

############################################################
# Check if the install script is
#   running in 'dry-run' mode.
#
# Returns:
#   0 in dry-run mode, 1 otherwise
############################################################
is_dry_run() {
    [ "$DRY_RUN" = "true" ] || return 1
}

############################################################
# Check if the install script is
#   running in non-interactive mode.
#
# Returns:
#   0 in non-interactive mode, 1 otherwise
############################################################
is_non_interactive() {
    [ "$NON_INTERACTIVE" = "true" ] || return 1
}

############################################################
# Check if we should skip installing hooks
#   into existing repositories.
#
# Returns:
#   0 if we should skip, 1 otherwise
############################################################
should_skip_install_into_existing_repositories() {
    [ "$SKIP_INSTALL_INTO_EXISTING" = "true" ] ||
        use_core_hookspath ||
        [ "$(git config --global githooks.useCoreHooksPath)" = "true" ] || return 1
}

############################################################
# Check if the install script is
#   running for a single repository only.
#
# Returns:
#   0 in single repository install mode, 1 otherwise
############################################################
is_single_repo_install() {
    [ "$SINGLE_REPO_INSTALL" = "true" ] || return 1
}

############################################################
# Check if the install script is
#   running with `--only-server-hooks` or if globally
#   configured to run only server hooks.
#
# Returns:
#   0 if only server hooks should be installed, 1 otherwise
############################################################
install_only_server_hooks() {
    [ "$INSTALL_ONLY_SERVER_HOOKS" = "true" ] ||
        [ "$(git config --global githooks.maintainOnlyServerHooks)" = "true" ] ||
        [ "$(git config --global githooks.maintainOnlyServerHooks)" = "Y" ] || # Legacy
        return 1
}

############################################################
# Check if the install script is
#   running with `--use-core-hookspath`.
#
# Returns:
#   0 if using `core.hooksPath`, 1 otherwise
############################################################
use_core_hookspath() {
    [ "$USE_CORE_HOOKSPATH" = "true" ] || return 1
}

############################################################
# Check if the install script is an autoupdate.
#
# Returns:
#   0 if its an update, 1 otherwise
############################################################
is_autoupdate() {
    [ "$INTERNAL_AUTOUPDATE" = "true" ] || return 1
}

############################################################
# Check if the install script is a post update step
#
# Returns:
#   0 if its an update, 1 otherwise
############################################################
is_postupdate() {
    [ "$INTERNAL_POSTUPDATE" = "true" ] || return 1
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
#   is a Git repository and sets `CWD_GIT_DIR` to the
#   git directory.
#
# Returns:
#   1 if failed, 0 otherwise
############################################################
get_cwd_git_dir() {
    if ! is_git_repo "$(pwd)"; then
        echo "! The current directory is not a Git repository" >&2
        unset CWD_GIT_DIR
        return 1
    else
        CWD_GIT_DIR="$(cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd)"
    fi
    return 0
}

############################################################
# Gets all worktrees attached to the given repository `$1`
#   and sets `REPO_WORKTREES`
#
# Returns: None
############################################################
get_repo_worktrees() {
    # This feature is kind of buggy in earlier version of git < 2.28.0
    # it returns a git directory instead of the work tree
    # We strip "/.git" from the output.
    git -C "$1" worktree list --porcelain | grep "worktree" | sed "s/worktree //g" | sed "s@/\.git@@"
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
        # Automatically find a template directory
        if ! find_git_hook_templates; then
            echo "! Git hook templates directory not found" >&2
            return 1
        fi
    else
        # The user provided a template directory, check it and
        # add `hooks` which is needed.
        if [ ! -d "$TARGET_TEMPLATE_DIR" ]; then
            echo "! Git hook templates directory does not exists" >&2
            return 1
        else
            TARGET_TEMPLATE_DIR="$TARGET_TEMPLATE_DIR/hooks"
        fi
    fi

    # TARGET_TEMPLATE_DIR is now `<template-dir>/hooks`
    # Create the `hooks` directory if it does not yet exist:
    if [ ! -d "$TARGET_TEMPLATE_DIR" ]; then
        if ! mkdir -p "$TARGET_TEMPLATE_DIR" >/dev/null 2>&1; then
            echo "! Could not create template folder \`$TARGET_TEMPLATE_DIR\`" >&2
            return 1
        fi
    fi

    # Up to now the directories would not have been set if
    # --use-core-hookspath is used, we set it now here.
    if ! is_dry_run && use_core_hookspath &&
        ! set_githooks_directory --core-hooks-path "$TARGET_TEMPLATE_DIR"; then
        echo "! Failed to set \`core.hooksPath\` to template dir" >&2
    fi
}

############################################################
# Try to find the directory where the Git
#   hook templates are currently.
#
# Sets ${TARGET_TEMPLATE_DIR} if found.
#
# Returns: 0 if successful found, otherwise 1
############################################################
find_git_hook_templates() {

    INSTALL_USES_CORE_HOOKS_PATH=$(git config --global githooks.useCoreHooksPath)

    # 1. from environment variables
    mark_directory_as_target "$GIT_TEMPLATE_DIR" "hooks" && return 0

    # 2. from git config
    if use_core_hookspath || [ "$INSTALL_USES_CORE_HOOKS_PATH" = "true" ]; then
        mark_directory_as_target "$(git config --global core.hooksPath)" && return 0
    elif ! use_core_hookspath || [ "$INSTALL_USES_CORE_HOOKS_PATH" = "false" ]; then
        mark_directory_as_target "$(git config --global init.templateDir)" "hooks" && return 0
    fi

    # 3. from the default location
    mark_directory_as_target "/usr/share/git-core/templates/hooks" && return 0

    # If we have an installation, and have not found the template folder by now...
    if [ -n "$INSTALL_USES_CORE_HOOKS_PATH" ]; then
        echo "! Your installation is corrupt." >&2
        echo "  The global value \`githooks.useCoreHooksPath = $INSTALL_USES_CORE_HOOKS_PATH\`" >&2
        echo "  is set but the corresponding hook templates directory" >&2
        echo "  is not found." >&2
        return 1
    fi

    # 4. Setup new folder if running non-interactively and no folder is found by now
    if is_non_interactive; then
        setup_new_templates_folder || return 1
        return 0 # we are finished either way here
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

                if ! is_dry_run &&
                    ! use_core_hookspath &&
                    ! set_githooks_directory --template-dir "$TEMPLATE_DIR"; then
                    echo "! Failed to set it up as Git template directory" >&2
                    return 1
                fi
                return 0
            fi

            return 1
        fi
    fi

    # 6. set up as new
    printf "Do you want to set up a new Git templates folder? [y/N] "
    read -r SETUP_NEW_FOLDER </dev/tty

    if [ "${SETUP_NEW_FOLDER}" = "y" ] || [ "${SETUP_NEW_FOLDER}" = "Y" ]; then
        setup_new_templates_folder || return 1
        return 0
    fi

    return 1
}

############################################################
# Sets the ${TARGET_TEMPLATE_DIR} variable if the
#   `$1` is a writable directory.
#   `$2` is a subfolder applied to the result.
# Returns: 0 if `$TARGET_TEMPLATE_DIR` is set, 1 otherwise
############################################################
mark_directory_as_target() {
    TARGET="$1"
    if [ -z "$TARGET" ]; then
        return 1
    fi

    # Check if its writable
    if [ -w "$TARGET" ]; then
        TARGET_TEMPLATE_DIR="$TARGET"
    else
        # Try to see if the path is given with a tilde
        TILDE_REPLACED=$(echo "$TARGET" | awk 'gsub("~", "'"$HOME"'", $0)')
        if [ -n "$TILDE_REPLACED" ] && [ -w "$TILDE_REPLACED" ]; then
            TARGET_TEMPLATE_DIR="$TILDE_REPLACED"
        else
            return 1
        fi
    fi

    # Add the subfolder if given
    if [ -n "$TARGET_TEMPLATE_DIR" ] && [ "$2" != "" ]; then
        TARGET_TEMPLATE_DIR="$TARGET_TEMPLATE_DIR/$2"
    fi

    return 0
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
# Returns: 0 if the $TARGET_TEMPLATE_DIR is set, 1 otherwise
############################################################
setup_new_templates_folder() {
    DEFAULT_TARGET="$INSTALL_DIR/templates"

    if is_non_interactive; then
        USER_TEMPLATES="$DEFAULT_TARGET"
    else
        unset USER_TEMPLATES
        printf "Enter the target folder: [%s] " "$DEFAULT_TARGET"
        read -r USER_TEMPLATES </dev/tty
        if [ -z "$USER_TEMPLATES" ]; then
            USER_TEMPLATES="$DEFAULT_TARGET"
        fi
    fi

    TILDE_REPLACED=$(echo "$USER_TEMPLATES" | awk 'gsub("~", "'"$HOME"'", $0)')
    if [ -z "$TILDE_REPLACED" ]; then
        TILDE_REPLACED="$USER_TEMPLATES"
    fi

    TARGET_TEMPLATE_DIR="${TILDE_REPLACED}/hooks"

    if ! is_dry_run && ! use_core_hookspath; then
        if ! mkdir -p "$TARGET_TEMPLATE_DIR" ||
            ! set_githooks_directory --template-dir "$USER_TEMPLATES"; then # Let this one go with or without a tilde
            echo "! Failed to set up the new Git templates folder" >&2
            return 1
        fi
    fi

    return 0
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

    if install_only_server_hooks; then
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

        if cp "$GITHOOKS_CLONE_DIR/base-template-wrapper.sh" "$HOOK_TEMPLATE" && chmod +x "$HOOK_TEMPLATE"; then
            echo "Git hook template ready: $HOOK_TEMPLATE"
        else
            echo "! Failed to setup the $HOOK template at $HOOK_TEMPLATE" >&2
            return 1
        fi
    done

    if install_only_server_hooks; then
        git config --global githooks.maintainOnlyServerHooks "true"
    fi

    return 0
}

############################################################
# Adds a Git alias for `$INSTALL_DIR/release/cli.sh`.
#
# Returns:
#   None
############################################################
install_command_line_tool() {

    mkdir -p "$INSTALL_DIR/bin" &&
        cp "$INSTALL_DIR/release/cli.sh" "$INSTALL_DIR/bin/githooks" &&
        chmod +x "$INSTALL_DIR/bin/githooks" &&
        git config --global alias.hooks "!\"$INSTALL_DIR/bin/githooks\"" &&
        echo "The command line helper is now available as 'git hooks <cmd>'" &&
        return

    echo "! Failed to setup the command line helper automatically." >&2
    echo "  If you'd like to do it manually, install the 'cli.sh' file from the" >&2
    echo "  repository into a folder on your PATH environment variable" >&2
    echo "  and make it executable." >&2
    echo "  Direct link to the script:" >&2
    echo "  https://raw.githubusercontent.com/rycus86/githooks/master/cli.sh" >&2
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
        if [ "$CURRENT_SETTING" = "true" ] || [ "$CURRENT_SETTING" = "Y" ]; then
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
        if is_dry_run; then
            echo "[Dry run] Automatic update checks would have been enabled"
        elif git config --global githooks.autoupdate.enabled true; then
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
        # e.g. spurious HEAD file or .git dir which does not mark a repository
        REPO_GIT_DIR=$(cd "$EXISTING" && cd "$(git rev-parse --git-common-dir 2>/dev/null)" && pwd)

        if is_git_repo "$REPO_GIT_DIR" && ! echo "$EXISTING_REPOSITORY_LIST" | grep -F -q "$REPO_GIT_DIR"; then
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
    PRE_START_DIR=$(git config --global --get githooks.previousSearchDir)
    # shellcheck disable=SC2181
    if [ $? -eq 0 ] && [ -n "$PRE_START_DIR" ]; then
        HAS_PRE_START_DIR="true"
    else
        PRE_START_DIR="$HOME"
    fi

    if [ "$HAS_PRE_START_DIR" = "true" ]; then
        QUESTION_PROMPT="[Y/n]"
    else
        QUESTION_PROMPT="[y/N]"
    fi

    if is_non_interactive; then
        if [ "$HAS_PRE_START_DIR" = "true" ]; then
            echo "Installing the hooks into existing repositories under $PRE_START_DIR"
            START_DIR="$PRE_START_DIR"
        else
            # non-interactive set and no pre start dir set -> abort
            return
        fi
    else
        printf 'Do you want to install the hooks into existing repositories? %s ' "$QUESTION_PROMPT"
        read -r DO_INSTALL </dev/tty

        if [ "$DO_INSTALL" != "y" ] && [ "$DO_INSTALL" != "Y" ]; then
            if [ "$HAS_PRE_START_DIR" != "true" ] || [ -n "$DO_INSTALL" ]; then
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

    git config --global githooks.previousSearchDir "$RAW_START_DIR"

    find_existing_git_dirs "$START_DIR"

    # Loop over all existing git dirs
    IFS="$IFS_NEWLINE"
    for EXISTING in $EXISTING_REPOSITORY_LIST; do
        unset IFS

        install_hooks_into_repo "$EXISTING"

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
            echo "! There is an LFS command statement in \`$HOOK_FILE\`."
            echo "  Githooks will call LFS hooks internally and LFS should not be called twice."
            printf "  Do you want to delete this hook instead of being disabled/backed up? (No, yes, all, skip all) [N/y/a/s] "

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

    LIST="$INSTALL_DIR/registered"
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

            if [ "$(git -C "$INSTALLED_REPO" rev-parse --is-inside-git-dir 2>/dev/null)" != "true" ]; then
                # Not existing git dir -> skip.
                true

            elif echo "$EXISTING_REPOSITORY_LIST" | grep -F -q "$INSTALLED_REPO"; then
                # We already installed to this repository, don't install
                echo "$INSTALLED_REPO" >>"$NEW_LIST"

            else
                # Existing registered repository, install.
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
                echo "The following remaining registered repositories in"
                echo "\`$LIST\`"
                echo "contain a Githooks installation:"
                sed -E "s/^/ - /" <"$INSTALL_LIST"
                printf 'Do you want to install to all of them? [Y/n] '

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

    INSTALLED="false"

    if [ "$IS_BARE" = "true" ]; then
        HOOK_NAMES="$MANAGED_SERVER_HOOK_NAMES"
    else
        HOOK_NAMES="$MANAGED_HOOK_NAMES"
    fi

    for HOOK_NAME in $HOOK_NAMES; do
        if is_dry_run; then
            INSTALLED="true"
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

        if cp "$GITHOOKS_CLONE_DIR/base-template-wrapper.sh" "$TARGET_HOOK" && chmod +x "$TARGET_HOOK"; then
            INSTALLED="true"
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
        TARGET_ROOT=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null)
        if [ -z "$TARGET_ROOT" ]; then
            TARGET_ROOT=$(cd "$TARGET" && cd "$(git rev-parse --git-common-dir 2>/dev/null)/.." && pwd)
        fi

        if [ -d "$TARGET_ROOT" ] && is_git_repo "$TARGET_ROOT" &&
            [ ! -f "$TARGET_ROOT/.githooks/README.md" ]; then

            NEVER_SETUP_README=$(git config --global githooks.noReadme)

            if [ "$NEVER_SETUP_README" = "yes" ] || [ "$SETUP_INCLUDED_README" = "s" ] || [ "$SETUP_INCLUDED_README" = "S" ]; then
                true # OK, we already said we want to skip all

            elif [ "$SETUP_INCLUDED_README" = "a" ] || [ "$SETUP_INCLUDED_README" = "A" ]; then
                mkdir -p "${TARGET_ROOT}/.githooks" &&
                    cp "$GITHOOKS_CLONE_DIR/.githooks/README.md" "$TARGET_ROOT/.githooks/README.md"

            else
                if [ ! -d "$TARGET_ROOT/.githooks" ]; then
                    echo "Looks like you don't have a .githooks folder"
                    echo "in the \`$TARGET_ROOT\` repository yet."
                    echo "  Would you like to create one with a README"
                    printf "  containing a brief overview of Githooks? (Yes, no, all, skip all) [Y/n/a/s] "
                else
                    echo "Looks like you don't have a README.md in the"
                    echo "  \`$TARGET_ROOT/.githooks\` folder yet."
                    echo "  A README file might help contributors and"
                    echo "  other team members learn about what is this for."
                    echo "  Would you like to add one now with"
                    printf "  a brief overview of Githooks? (Yes, no, all, skip all) [Y/n/a/s] "
                fi

                read -r SETUP_INCLUDED_README </dev/tty

                if [ -z "$SETUP_INCLUDED_README" ] ||
                    [ "$SETUP_INCLUDED_README" = "y" ] || [ "$SETUP_INCLUDED_README" = "Y" ] ||
                    [ "$SETUP_INCLUDED_README" = "a" ] || [ "$SETUP_INCLUDED_README" = "A" ]; then

                    mkdir -p "${TARGET_ROOT}/.githooks" &&
                        cp "$GITHOOKS_CLONE_DIR/.githooks/README.md" "${TARGET_ROOT}/.githooks/README.md"
                fi

                if [ "$SETUP_INCLUDED_README" = "s" ] || [ "$SETUP_INCLUDED_README" = "S" ]; then
                    printf "Would you like to always skip adding the Githooks README in the future? [y/N] "
                    read -r ALWAYS_SKIP_ADDING_README </dev/tty

                    if [ "$ALWAYS_SKIP_ADDING_README" = "y" ] || [ "$ALWAYS_SKIP_ADDING_README" = "Y" ]; then
                        git config --global githooks.noReadme "yes"
                    fi
                fi
            fi
        fi
    fi

    if [ "$INSTALLED" = "true" ]; then
        if is_dry_run; then
            echo "[Dry run] Hooks would have been installed into $TARGET"
        else
            register_repo "$TARGET"
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
# Adds the repository to the registration list
#  `githooks.registered`
#
# Returns: 0
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

    # Mark the repo as registered.
    (git -C "$CURRENT_REPO" config --local githooks.registered "true")

    return 0
}

############################################################
# Optionally setup global shared hook repositories.
#
# Returns:
#   None
############################################################
setup_shared_hook_repositories() {
    if [ -n "$(git config --global --get-all githooks.shared)" ]; then
        echo "Looks like you already have shared hook"
        printf "repositories setup, do you want to change them now? [y/N] "
    else
        echo "You can set up shared hook repositories to avoid"
        echo "duplicating common hooks across repositories you"
        echo "work on. See information on what are these in the"
        echo "project's documentation at:"
        echo "https://github.com/rycus86/githooks#shared-hook-repositories"
        echo "Note: you can also have a .githooks/.shared file listing the"
        echo "repositories where you keep the shared hook files"
        printf "Would you like to set up shared hook repos now? [y/N] "
    fi

    read -r DO_SETUP </dev/tty
    if [ "$DO_SETUP" != "y" ] && [ "$DO_SETUP" != "Y" ]; then return; fi

    echo "OK, let's input them one-by-one and leave the input empty to stop."

    PROVIDED="false"
    while true; do
        printf "Enter the clone URL of a shared repository: "
        read -r SHARED_REPO </dev/tty
        if [ -z "$SHARED_REPO" ]; then break; fi

        if [ -n "$SHARED_REPO" ]; then

            if [ "$PROVIDED" = "false" ]; then
                git config --global --unset-all githooks.shared
            fi

            if git config --global --add githooks.shared "$SHARED_REPO"; then
                PROVIDED="true"
            else
                PROVIDED="error"
                break
            fi
        fi
    done

    if [ "$PROVIDED" = "false" ] &&
        git config --global --unset githooks.shared; then
        echo "Shared hook repositories are now unset. If you want to set them up again in the future, run this script again, or change the 'githooks.shared' Git config variable manually."
        echo "Note: shared hook repos listed in the .githooks/.shared file will still be executed"
    elif [ "$PROVIDED" = "true" ]; then
        # Trigger the shared hook repository checkout manually
        sh "$GITHOOKS_CLONE_DIR/cli.sh" shared update --global

        echo "Shared hook repositories have been set up."
        echo "You can change them any time by running this script"
        echo "again, or manually by changing the 'githooks.shared'"
        echo "Git config variable."
        echo "Note: you can also list the shared hook repos per"
        echo "project within the .githooks/.shared file"

        printf "Do you want to trust all shared hook repositories containing a trust-all file, both now and in the future? [y/N]"
        read -r TRUST_SHARED_REPO </dev/tty

        if [ "$TRUST_SHARED_REPO" = "y" ] || [ "$TRUST_SHARED_REPO" = "Y" ]; then
            git config --global githooks.trust.all Y
            echo "Shared hook repositories are now always trusted if they contain a '.githooks/trust-all' file."
            echo "If you want to disable this in the future, run 'git config --global githooks.trust.all N',"
            echo "or change the 'githooks.trust.all' git configuration variable manually."
        elif [ "$TRUST_SHARED_REPO" = "n" ] || [ "$TRUST_SHARED_REPO" = "N" ]; then
            git config --global githooks.trust.all N
            echo "You decided not to trust shared hook repositories containing a '.githooks/trust-all' file automatically."
            echo "If you want to enable this in the future, run 'git config --global githooks.trust.all Y',"
            echo "or execute 'git hooks shared trust revoke'."
        fi

    else
        echo "! Failed to set up the shared hook repositories" >&2
        git config --global --unset-all githooks.shared >/dev/null 2>&1
    fi
}

############################################################
# Sets the githooks templatedir or hookspath
#   config variable
#
# Parameters:
#   1: path for templateDir or hooksPath
#
# Returns: 0 if successful, 1 otherwise
############################################################
set_githooks_directory() {
    if [ "$1" = "--core-hooks-path" ]; then
        git config --global githooks.useCoreHooksPath true
        git config --global githooks.pathForUseCoreHooksPath "$2"
        git config --global core.hooksPath "$2"

        CURRENT_TEMPLATE_DIR=$(git config --global init.templateDir)

        # shellcheck disable=SC2012
        if [ -d "$CURRENT_TEMPLATE_DIR" ] &&
            [ "$(ls -1 "$CURRENT_TEMPLATE_DIR/hooks" 2>/dev/null | wc -l)" != "0" ]; then
            echo "! The \`init.templateDir\` setting is currently set to" >&2
            echo "  \`$CURRENT_TEMPLATE_DIR\`" >&2
            HOOKS_GET_IGNORED=1
        fi

        # shellcheck disable=SC2012
        if [ -d "$GIT_TEMPLATE_DIR" ] &&
            [ "$(ls -1 "$GIT_TEMPLATE_DIR/hooks" 2>/dev/null | wc -l)" != "0" ]; then
            echo "! The environment variable \`GIT_TEMPLATE_DIR\` is currently set to" >&2
            echo "  \`$GIT_TEMPLATE_DIR\`" >&2
            HOOKS_GET_IGNORED=1
        fi

        if [ "$HOOKS_GET_IGNORED" = "1" ]; then
            echo "  and contains Git hooks which get installed but" >&2
            echo "  ignored because \`core.hooksPath\` is also set." >&2
            echo "  It is recommended to either remove the files or run" >&2
            echo "  the Githooks installation without the \`--use-core-hookspath\`" >&2
            echo "  parameter" >&2
            unset HOOKS_GET_IGNORED
        fi

    elif [ "$1" = "--template-dir" ]; then
        git config --global githooks.useCoreHooksPath false
        git config --global init.templateDir "$2"

        CURRENT_CORE_HOOKS_PATH=$(git config --global core.hooksPath)
        if [ -n "$CURRENT_CORE_HOOKS_PATH" ]; then
            echo "! The \`core.hooksPath\` setting is currently set to" >&2
            echo "  \`$CURRENT_CORE_HOOKS_PATH\`" >&2
            echo "  This could mean that Githooks hooks will be ignored" >&2
            echo "  Either unset \`core.hooksPath\` or run the Githooks" >&2
            echo "  installation with the --use-core-hookspath parameter" >&2
        fi
    fi

    return 0
}

#####################################################
# Safely execute a git command in the standard
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
# Updates the update clone in the install folder.
#   Sets the variables
#   - `GITHOOKS_CLONE_CREATED`
#   - `GITHOOKS_CLONE_UPDATED` (also for clone)
#   - `GITHOOKS_CLONE_UPDATED_FROM_COMMIT`
#
#   `GITHOOKS_CLONE_UPDATED_FROM_COMMIT` is empty if
#    no update happened or the Git null ref
#    "000..000" if a new cloned happened or
#   the commit SHA from where was updated.
#
# Returns:
#   1 if failed, 0 otherwise
#####################################################
update_release_clone() {

    echo "Updating Githooks installation ..."

    GITHOOKS_CLONE_CREATED="false"
    GITHOOKS_CLONE_UPDATED="false"
    GITHOOKS_CLONE_UPDATED_FROM_COMMIT=""

    CREATE_NEW_CLONE="false"

    # We do a fresh clone if:
    # - we have an existing clone AND
    #   - url or branch of the existing clone does not match the settings OR
    #   - the existing clone has modifications (should not be the case)
    # - we do not have an existing clone

    # If not set by the user, check the config for url and branch
    if [ -z "$GITHOOKS_CLONE_URL" ]; then
        GITHOOKS_CLONE_URL=$(git config --global githooks.cloneUrl)
    fi
    if [ -z "$GITHOOKS_CLONE_BRANCH" ]; then
        GITHOOKS_CLONE_BRANCH=$(git config --global githooks.cloneBranch)
    fi

    if is_git_repo "$GITHOOKS_CLONE_DIR"; then

        URL=$(execute_git "$GITHOOKS_CLONE_DIR" config remote.origin.url 2>/dev/null)
        BRANCH=$(execute_git "$GITHOOKS_CLONE_DIR" symbolic-ref -q --short HEAD 2>/dev/null)

        if [ "$URL" != "$GITHOOKS_CLONE_URL" ] ||
            [ "$BRANCH" != "$GITHOOKS_CLONE_BRANCH" ]; then

            CREATE_NEW_CLONE="true"

            # During an autoupdate we would silently erase/reclone
            # which is not so good, therefore we abort here.
            if is_autoupdate; then
                echo "! Cannot pull updates because \`origin\` of update clone" >&2
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
        fi

        # During an autoupdate we also warn when
        # the update clone is dirty which it really
        # should not be and abort.
        if is_autoupdate && ! execute_git "$GITHOOKS_CLONE_DIR" diff-index --quiet HEAD >/dev/null 2>&1; then
            echo "! Cannot pull updates because the update clone" >&2
            echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
            echo "  is dirty! Either fix this or delete the clone" >&2
            echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
            echo "  to trigger a new checkout." >&2
            return 1
        fi

    else
        CREATE_NEW_CLONE="true"
    fi

    if [ "$CREATE_NEW_CLONE" = "true" ]; then

        clone_release_repository || return 1
        GITHOOKS_CLONE_UPDATED_FROM_COMMIT="0000000000000000000000000000000000000000"
        GITHOOKS_CLONE_CREATED="true"
        GITHOOKS_CLONE_UPDATED="true"

    else
        echo "Fetching Githooks updates ..."
        FETCH_OUTPUT=$(
            execute_git "$GITHOOKS_CLONE_DIR" fetch origin "$GITHOOKS_CLONE_BRANCH" 2>&1
        )

        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo "! Fetching updates in" >&2
            echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
            echo "  failed with:" >&2
            echo "  -------------------" >&2
            echo "$FETCH_OUTPUT" >&2
            echo "  -------------------" >&2
            return 1
        fi

        CURRENT_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse "$GITHOOKS_CLONE_BRANCH" 2>/dev/null)
        UPDATE_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse "origin/$GITHOOKS_CLONE_BRANCH" 2>/dev/null)

        if [ "$CURRENT_COMMIT" != "$UPDATE_COMMIT" ]; then
            # Fast forward merge in the changes if possible
            echo "Merging Githooks updates ..."
            MERGE_OUTPUT=$(
                execute_git "$GITHOOKS_CLONE_DIR" merge --ff-only "origin/$GITHOOKS_CLONE_BRANCH" 2>&1
            )

            # shellcheck disable=SC2181
            if [ $? -ne 0 ]; then
                echo "! Fast-forward merging updates in" >&2
                echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
                echo "  failed with:" >&2
                echo "  -------------------" >&2
                echo "$MERGE_OUTPUT" >&2
                echo "  -------------------" >&2
                return 1
            fi

            # shellcheck disable=SC2034
            GITHOOKS_CLONE_UPDATED_FROM_COMMIT="$CURRENT_COMMIT"
            GITHOOKS_CLONE_UPDATED="true"
        fi

        # Ensure we have clone url and branch set (technically not necessary)
        # its possible to have them not set till now...
        git config --global githooks.cloneUrl "$GITHOOKS_CLONE_URL"
        git config --global githooks.cloneBranch "$GITHOOKS_CLONE_BRANCH"
    fi

    GITHOOKS_CLONE_CURRENT_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse HEAD)
    GITHOOKS_CLONE_CURRENT_COMMIT_DATE=$(execute_git "$GITHOOKS_CLONE_DIR" log -1 "--date=format:%y%m.%d%H%M" --format="%cd" HEAD)

    echo "Githooks clone at version: $GITHOOKS_CLONE_CURRENT_COMMIT_DATE-$(echo "$GITHOOKS_CLONE_CURRENT_COMMIT" | cut -c -6)"

    return 0
}

#####################################################
# Checks if a clone was created.
#
# Returns:
#   0 if an update was applied, 1 otherwise
#####################################################
is_clone_created() {
    [ "$GITHOOKS_CLONE_CREATED" = "true" ] || return 1
}

#####################################################
# Checks if an update was applied
#  in the release clone. A clone is also an update.
#
# Returns:
#   0 if an update was applied, 1 otherwise
#####################################################
is_clone_updated() {
    [ "$GITHOOKS_CLONE_UPDATED" = "true" ] || return 1
}

############################################################
# Clone the URL `$GITHOOKS_CLONE_URL` into the install
#   folder `$GITHOOKS_CLONE_DIR` for further updates.
#
# Returns: 0 if successful, 1 otherwise
############################################################
clone_release_repository() {

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

    echo "Cloning \`$GITHOOKS_CLONE_URL\` to \`$GITHOOKS_CLONE_DIR\` ..."

    CLONE_OUTPUT=$(
        git clone \
            -c core.hooksPath=/dev/null \
            --template=/dev/null \
            --depth=1 \
            --single-branch \
            --branch "$GITHOOKS_CLONE_BRANCH" \
            "$GITHOOKS_CLONE_URL" "$GITHOOKS_CLONE_DIR" 2>&1
    )

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
# Run the install from the update clone.

# Returns: 0 if successful, 1 otherwise
############################################################
run_internal_install() {
    INSTALL_SCRIPT="$GITHOOKS_CLONE_DIR/install.sh"
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        echo "! No install script in folder \`$GITHOOKS_CLONE_DIR/\`" >&2
        return 1
    fi

    # shellcheck disable=SC2086
    sh "$INSTALL_SCRIPT" $ADD_ARGS \
        --internal-install \
        --internal-updated-from "$GITHOOKS_CLONE_UPDATED_FROM_COMMIT" \
        "$@" || return 1
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
    echo "Please support the project by starring the project"
    echo "at https://github.com/rycus86/githooks, and report"
    echo "bugs or missing features or improvements as issues."
    echo "Thanks!"
}

# Start the installation process
execute_installation "$@" || exit 1
