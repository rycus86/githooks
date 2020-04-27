#!/bin/sh
#
# Installs the base Git hook templates from https://github.com/rycus86/githooks
#   and performs some optional setup for existing repositories.
#   See the documentation in the project README for more information.
#
# Version: 2004.272130-08fba9

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

    # Clone the repository to the install folder
    # and run the install.sh from there.
    if ! is_running_internal_install && ! is_update_only; then
        update_release_clone || return 1
        run_internal_install "$@" || return 1
        return 0
    fi

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
# Checks if we are running an internal install
#  from the release repository.
#
# Returns: 0 if `true`, 1 oterhwise
############################################################
is_running_internal_install() {
    if [ "$INTERNAL_INSTALL" = "yes" ]; then
        return 0
    fi
    return 1
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
        elif [ "$p" = "--prefix" ]; then
            : # nothing to do here
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
        elif [ "$p" = "--update-clone-url" ]; then
            : # nothing to do here
        elif [ "$prev_p" = "--update-clone-url" ] && (echo "$p" | grep -qvE '^\-\-.*'); then
            GITHOOKS_CLONE_URL="$p"
        elif [ "$p" = "--update-clone-branch" ]; then
            : # nothing to do here
        elif [ "$prev_p" = "--update-clone-branch" ] && (echo "$p" | grep -qvE '^\-\-.*'); then
            GITHOOKS_CLONE_BRANCH="$p"
        else
            echo "! Unknown argument \`$p\`" >&2
            exit 1
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

        if cp "$INSTALL_DIR/release/base-template.sh" "$HOOK_TEMPLATE" && chmod +x "$HOOK_TEMPLATE"; then
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
        cp "$INSTALL_DIR/release/cli.sh" "$INSTALL_DIR/bin/githooks" &&
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

        if cp "$INSTALL_DIR/release/base-template.sh" "$TARGET_HOOK" && chmod +x "$TARGET_HOOK"; then
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
                    cp "$INSTALL_DIR/release/.githooks/README.md" "${TARGET_ROOT}/.githooks/README.md"

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
                        cp "$INSTALL_DIR/release/.githooks/README.md" "${TARGET_ROOT}/.githooks/README.md"
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
        cp "$INSTALL_DIR/release/base-template.sh" ".githooks.shared.trigger" &&
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

#####################################################
# Updates the update clone in the install folder.
#
# Returns:
#   1 if failed, 0 otherwise
#####################################################
update_release_clone() {

    CLONE_DIR="$INSTALL_DIR/release"
    PULL_ONLY="true"

    # We do a fresh clone if:
    # - we have an existing clone AND
    #   - url or branch of the existing clone does not match the settings OR
    #   - the existing clone has modifications (should not be the case)
    # - we dont have an existing clone

    # If not set by the user, check the config for url and branch
    if [ -z "$GITHOOKS_CLONE_URL" ]; then
        GITHOOKS_CLONE_URL=$(git config --global githooks.autoupdate.updateCloneUrl)
    fi
    if [ -z "$GITHOOKS_CLONE_BRANCH" ]; then
        GITHOOKS_CLONE_BRANCH=$(git config --global githooks.autoupdate.updateCloneBranch)
    fi

    if is_git_repo "$CLONE_DIR"; then
        URL=$(git -C "$CLONE_DIR" config remote.origin.url)
        BRANCH=$(git -C "$CLONE_DIR" symbolic-ref -q --short HEAD)

        if [ "$URL" != "$GITHOOKS_CLONE_URL" ] ||
            [ "$BRANCH" != "$GITHOOKS_CLONE_BRANCH" ] ||
            ! git -C "$CLONE_DIR" diff-index --quiet HEAD; then
            PULL_ONLY="false"
        fi
    else
        PULL_ONLY="false"
    fi

    if [ "$PULL_ONLY" = "true" ]; then
        PULL_OUTPUT=$(
            git -C "$CLONE_DIR" \
                --work-tree="$CLONE_DIR" \
                --git-dir="$CLONE_DIR/.git" \
                -c core.hooksPath=/dev/null pull origin "$GITHOOKS_CLONE_BRANCH" 2>&1
        )

        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo "! Pulling updates in \`$CLONE_DIR\` failed with:" >&2
            echo "$PULL_OUTPUT" >&2
            return 1
        fi
    else
        clone_release_repository || return 1
    fi

    return 0
}

############################################################
# Clone the URL `$GITHOOKS_CLONE_URL` into the install
# folder `$INSTALL_DIR/release` for further updates.
#
# Returns: 0 if succesful, 1 otherwise
############################################################
clone_release_repository() {

    if [ -z "$GITHOOKS_CLONE_URL" ]; then
        GITHOOKS_CLONE_URL="https://github.com/rycus86/githooks.git"
    fi

    if [ -z "$GITHOOKS_CLONE_BRANCH" ]; then
        GITHOOKS_CLONE_BRANCH="master"
    fi

    if [ -d "$INSTALL_DIR/release" ]; then
        if ! rm -rf "$INSTALL_DIR/release" >/dev/null 2>&1; then
            echo "! Failed to remove an existing githooks release repository" >&2
            return 1
        fi
    fi

    echo "Cloning \`$GITHOOKS_CLONE_URL\` to \`$INSTALL_DIR/release\` ..."

    CLONE_OUTPUT=$(
        git clone \
            -c core.hooksPath=/dev/null \
            --depth 1 \
            --single-branch \
            --branch "$GITHOOKS_CLONE_BRANCH" \
            "$GITHOOKS_CLONE_URL" "$INSTALL_DIR/release" 2>&1
    )

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        echo "! Cloning \`$GITHOOKS_CLONE_URL\` to \`$INSTALL_DIR/release\` failed with output: " >&2
        echo "$CLONE_OUTPUT" >&2
        return 1
    fi

    git config --global githooks.autoupdate.updateCloneUrl "$GITHOOKS_CLONE_URL"
    git config --global githooks.autoupdate.updateCloneBranch "$GITHOOKS_CLONE_BRANCH"

    return 0
}

############################################################
# Run the install from the update clone.

# Returns: 0 if succesful, 1 otherwise
############################################################
run_internal_install() {
    if [ ! -f "$INSTALL_DIR/release/install.sh" ]; then
        echo "! No install script in folder \`$INSTALL_DIR/release/\`" >&2
        return 1
    fi

    INTERNAL_INSTALL="yes" sh "$INSTALL_DIR/release/install.sh" "$@" || return 1
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
