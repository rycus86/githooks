#!/bin/sh
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
# Legacy version number. Not used anymore, but old installs read it.
# Version: 9912.310000-000000

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
    exec        Executes a hook script on demand
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

    GITHOOKS_CLONE_DIR="$INSTALL_DIR/release"
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
    IFS_NEWLINE="
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
#   some combination of these, intended to
#   enable or disable exactly one hook found.
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
            echo "! For shared repositories, either the trigger type" >&2
            echo "  the hook name or both needs to be given" >&2
            return 1
        fi

        if [ ! -d "$INSTALL_DIR/shared" ]; then
            echo "! No shared repositories found" >&2
            return 1
        fi

        IFS="$IFS_NEWLINE"
        for SHARED_ROOT in "$INSTALL_DIR/shared/"*; do
            unset IFS

            if [ ! -d "$SHARED_ROOT" ]; then
                continue
            fi

            REMOTE_URL=$(git -C "$SHARED_ROOT" config --get remote.origin.url)

            if [ -f "$(pwd)/.githooks/.shared" ]; then
                SHARED_LOCAL_REPOS_LIST=$(grep -E "^[^#\n\r ].*$" <"$(pwd)/.githooks/.shared")
                ACTIVE_LOCAL_REPO=$(echo "$SHARED_LOCAL_REPOS_LIST" | grep -F -o "$REMOTE_URL")
            else
                ACTIVE_LOCAL_REPO=""
            fi

            ACTIVE_GLOBAL_REPO=$(git config --global --get-all githooks.shared | grep -o "$REMOTE_URL")

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

            IFS="$IFS_NEWLINE"
        done

        echo "! Sorry, cannot find any shared hooks that would match that" >&2
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

                IFS="$IFS_NEWLINE"
                for HOOK_FILE in "$HOOK_DIR"/*; do
                    unset IFS

                    HOOK_ITEM=$(basename "$HOOK_FILE")
                    if [ "$HOOK_ITEM" = "$1" ]; then
                        HOOK_PATH="$HOOK_FILE"
                    fi

                    IFS="$IFS_NEWLINE"
                done
            done
        fi
    fi

    if [ -z "$HOOK_PATH" ]; then
        echo "! Sorry, cannot find any hooks that would match that" >&2
        return 1
    elif echo "$HOOK_PATH" | grep -F -qv "/.githooks"; then
        if [ -d "$HOOK_PATH/.githooks" ]; then
            HOOK_PATH="$HOOK_PATH/.githooks"
        else
            echo "! Sorry, cannot find any hooks that would match that" >&2
            return 1
        fi
    fi
}

#####################################################
# Finds a hook file path based on trigger name,
#   file name, relative or absolute path, or
#   some combination of these, intended to
#   loosely match for executing the ones found.
#
# Sets the ${HOOK_PATHS} environment variable,
#   with the list of matching hook paths.
#
# Returns:
#   0 on success, 1 when no hooks found
#####################################################
find_hook_path_to_execute() {
    if [ -z "$1" ]; then
        echo "! Either the trigger type, the hook name or both needs to be given" >&2
        return 1

    elif [ -n "$1" ] && [ -n "$2" ]; then
        if [ -n "$EXACT_MATCH" ]; then
            SEARCH_PATTERN="$1/$2\$"
        else
            SEARCH_PATTERN="$1/.*$2.*"
        fi

    else
        TRIGGER_TYPES="(applypatch-msg|pre-applypatch|post-applypatch|pre-commit|prepare-commit-msg|commit-msg|post-commit"
        TRIGGER_TYPES="${TRIGGER_TYPES}|pre-rebase|post-checkout|post-merge|pre-push|pre-receive|update|post-receive"
        TRIGGER_TYPES="${TRIGGER_TYPES}|post-update|push-to-checkout|pre-auto-gc|post-rewrite|sendemail-validate)"

        if echo "$1" | grep -qE "^${TRIGGER_TYPES}$"; then
            SEARCH_PATTERN="$1/.*"
        else
            if [ -n "$EXACT_MATCH" ]; then
                SEARCH_PATTERN="${TRIGGER_TYPES}/$1\$"
            else
                SEARCH_PATTERN="${TRIGGER_TYPES}/.*$1.*"
            fi
        fi
    fi

    HOOK_PATHS=""
    IFS="$IFS_NEWLINE"
    for TARGET_HOOK in $(find "$(pwd)/.githooks" -type f | grep -E "/\.githooks/$SEARCH_PATTERN" | sort); do
        if [ -z "$HOOK_PATHS" ]; then
            HOOK_PATHS="$TARGET_HOOK"
        else
            HOOK_PATHS="$HOOK_PATHS
$TARGET_HOOK"
        fi
    done
    unset IFS

    if [ ! -d "$INSTALL_DIR/shared" ]; then
        # No shared repositories found
        return
    fi

    IFS="$IFS_NEWLINE"
    for SHARED_ROOT in "$INSTALL_DIR/shared/"*; do
        unset IFS

        if [ ! -d "$SHARED_ROOT" ]; then
            continue
        fi

        REMOTE_URL=$(git -C "$SHARED_ROOT" config --get remote.origin.url)

        if [ -f "$(pwd)/.githooks/.shared" ]; then
            SHARED_LOCAL_REPOS_LIST=$(grep -E "^[^#\n\r ].*$" <"$(pwd)/.githooks/.shared")
            ACTIVE_LOCAL_REPO=$(echo "$SHARED_LOCAL_REPOS_LIST" | grep -F -o "$REMOTE_URL")
        else
            ACTIVE_LOCAL_REPO=""
        fi

        ACTIVE_GLOBAL_REPO=$(git config --global --get-all githooks.shared | grep -o "$REMOTE_URL")

        if [ "$ACTIVE_LOCAL_REPO" != "$REMOTE_URL" ] && [ "$ACTIVE_GLOBAL_REPO" != "$REMOTE_URL" ]; then
            continue
        fi

        if [ -d "$SHARED_ROOT/.githooks" ]; then
            SHARED_ROOT_SEARCH_START="$SHARED_ROOT/.githooks"
        else
            SHARED_ROOT_SEARCH_START="$SHARED_ROOT"
        fi

        IFS="$IFS_NEWLINE"
        for TARGET_HOOK in $(find "$SHARED_ROOT_SEARCH_START" -type f | grep -E "${SHARED_ROOT_SEARCH_START}/${SEARCH_PATTERN}" | sort); do
            if [ -z "$HOOK_PATHS" ]; then
                HOOK_PATHS="$TARGET_HOOK"
            else
                HOOK_PATHS="$HOOK_PATHS
$TARGET_HOOK"
            fi
        done
        unset IFS

        IFS="$IFS_NEWLINE"
    done
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
        echo "! The current directory \`$(pwd)\` does not seem" >&2
        echo "  to be the root of a Git repository!" >&2
        exit 1
    fi

    if [ "$1" = "-a" ] || [ "$1" = "--all" ]; then
        git config githooks.disable true &&
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
        echo "The current directory \`$(pwd)\` does not seem to be the root of a Git repository!"
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
        echo "The current directory \`$(pwd)\` does not seem to be the root of a Git repository!"
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
# Execute a specific hook on demand.
#
# Returns:
#   1 if the current directory is not a Git repo,
#   0 otherwise
#####################################################
execute_hook() {
    if [ "$1" = "help" ]; then
        print_help_header
        echo "
git hooks exec [--exact] [trigger] [hook-script]
git hooks exec [--exact] [hook-script]
git hooks exec [--exact] [trigger]

    Executes a hook script on demand.
    During these executions, the \`GITHOOKS_ON_DEMAND_EXEC\` environment
    variable will be set, hook scripts can use that for conditional logic.
    The \`trigger\` parameter should be the name of the Git event if given.
    The \`hook-script\` can be the name of the file to execute, or its
    relative path, or an absolute path, we will try to find it.
    If the \`--exact\` flag is given, only hook scripts matching exactly
    will be returned, otherwise all hook scripts matching the substring.
"
        return
    fi

    if ! is_running_in_git_repo_root; then
        echo "! The current directory \`$(pwd)\` does not seem to be the root of a Git repository!" >&2
        exit 1
    fi

    if [ "$1" = "--exact" ]; then
        EXACT_MATCH=1
        shift
    fi

    if [ -z "$1" ]; then
        echo "! Missing [hook-script] or [trigger] argument, see git hooks exec help" >&2
        exit 1

    elif [ -n "$2" ]; then
        REQUESTED_HOOK_TYPE="$1"
        ACCEPTED_HOOK_TYPES="
        applypatch-msg pre-applypatch post-applypatch
        pre-commit prepare-commit-msg commit-msg post-commit
        pre-rebase post-checkout post-merge pre-push
        pre-receive update post-receive post-update
        push-to-checkout pre-auto-gc post-rewrite sendemail-validate"

        if ! echo "$ACCEPTED_HOOK_TYPES" | grep -qE "\b$REQUESTED_HOOK_TYPE\b"; then
            echo "! Unknown trigger type: $REQUESTED_HOOK_TYPE" >&2
            echo "  See git hooks exec help for usage" >&2
            exit 1
        fi

    elif [ -n "$3" ]; then
        echo "! Unexpected argument: $3" >&2
        echo "  See git hooks exec help for usage" >&2
        exit 1
    fi

    find_hook_path_to_execute "$@" || exit 1

    if [ -z "$HOOK_PATHS" ]; then
        echo "! Sorry, cannot find any hooks that would match that" >&2
        exit 1
    fi

    AGGREGATE_RESULT="0"

    IFS="$IFS_NEWLINE"
    for HOOK_FILE in ${HOOK_PATHS}; do
        unset IFS

        if [ -x "$HOOK_FILE" ]; then
            # Run as an executable file
            GITHOOKS_ON_DEMAND_EXEC=1 "$HOOK_FILE"
            RUN_RESULT="$?"

        elif [ -f "$HOOK_FILE" ]; then
            # Run as a Shell script
            GITHOOKS_ON_DEMAND_EXEC=1 sh "$HOOK_FILE"
            RUN_RESULT="$?"

        else
            echo "! Unable to run hook file: $HOOK_FILE}" >&2
            RUN_RESULT="1"
        fi

        [ "$RUN_RESULT" -gt "$AGGREGATE_RESULT" ] && AGGREGATE_RESULT="$RUN_RESULT"

        IFS="$IFS_NEWLINE"
    done
    unset IFS

    exit "$AGGREGATE_RESULT"
}

#####################################################
# Returns the SHA1 hash of the hook file
#   passed in as the first argument.
#####################################################
get_hook_checksum() {
    git hash-object "$1" 2>/dev/null
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
git hooks trust [--local|--global]
git hooks trust [revoke] 
git hooks trust [delete] 
git hooks trust [forget] [--local|--global]

    Sets up, or reverts the trusted setting for the local repository.
    When called without arguments, it marks the local repository as trusted.
    The \`revoke\` argument resets the already accepted trust setting,
    and the \`delete\` argument also deletes the trusted marker.
    The \`forget\` option unsets the trust setting, asking for accepting
    it again next time, if the repository is marked as trusted.
"
        return
    fi
    
    
    # shellcheck disable=SC1009
    if [ "$1" = "--local" ] ; then
        if ! is_running_in_git_repo_root; then
            echo "The current directory \`$(pwd)\` does not seem to be the root of a Git repository!"
            exit 1
        fi
        mkdir -p .githooks &&
            touch .githooks/trust-all &&
            git config githooks.trust.all Y &&
            echo "The current repository is now trusted." &&
            echo_if_non_bare_repo "  Do not forget to commit and push the trust marker!" &&
            return

        echo "! Failed to mark the current repository as trusted" >&2
        exit 1
    elif [ "$1" = "--global" ]; then
        GLOBAL_TRUST=$(git config --global --get githooks.trust.all)
        if [ "${GLOBAL_TRUST}" = "" ] || [ "${GLOBAL_TRUST}" = "N" ]; then
            git config --global githooks.trust.all Y
            echo "Global hook are now trusted when they contains a .githooks/trust-all file"
            return
        elif [ "${GLOBAL_TRUST}" = "Y" ]; then
            echo "Global hook are already trusted"
            return
        fi
    fi

    if [ "$1" = "forget" ]; then
        if [ "$2" = "--local" ]; then
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
        elif [ "$2" = "--global" ]; then
            git config --global --unset githooks.trust.all
            echo "Global repository are no longer trusted."
            return
        else
            echo "! Usage: \`git hooks trust forget [--local|--global] \`" >&2
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
# Checks if Githhoks is set up correctly,
#   and that other git settings do not prevent it
#   from executing scripts.
#####################################################
check_git_hooks_setup_is_correct() {
    if [ -n "$(git config core.hooksPath)" ]; then
        if [ "true" != "$(git config githooks.useCoreHooksPath)" ]; then
            echo "! WARNING" >&2
            echo "  \`git config core.hooksPath\` is set to $(git config core.hooksPath)," >&2
            echo "  but Githooks is not configured to use that folder," >&2
            echo "  which could mean the hooks in this repository are not run by Githooks" >&2
            echo >&2
        fi
    else
        if [ "true" = "$(git config githooks.useCoreHooksPath)" ]; then
            echo "! WARNING" >&2
            echo "  Githooks is configured to consider \`git config core.hooksPath\`," >&2
            echo "  but that git setting is not currently set," >&2
            echo "  which could mean the hooks in this repository are not run by Githooks" >&2
            echo >&2
        fi
    fi
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
        echo "The current directory \`$(pwd)\` does not seem to be the root of a Git repository!"
        exit 1
    fi

    check_git_hooks_setup_is_correct

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
        SHARED_REPOS_LIST=$(git config --global --get-all githooks.shared)
        IFS="$IFS_NEWLINE"
        for SHARED_ITEM in $(list_hooks_in_shared_repos "$LIST_TYPE"); do
            GLOBAL="true"
            unset IFS
            if [ -d "$SHARED_ITEM" ]; then
                for LIST_ITEM in "$SHARED_ITEM"/*; do
                    ITEM_NAME=$(basename "$LIST_ITEM")
                    ITEM_STATE=$(get_hook_state "$LIST_ITEM" "$@" )
                    LIST_OUTPUT="$LIST_OUTPUT
  - $ITEM_NAME (${ITEM_STATE} / shared:global)"
                done

            elif [ -f "$SHARED_ITEM" ]; then
                ITEM_STATE=$(get_hook_state "$SHARED_ITEM" )
                LIST_OUTPUT="$LIST_OUTPUT
  - $LIST_TYPE (file / ${ITEM_STATE} / shared:global)"
            fi

            IFS="$IFS_NEWLINE"
        done

        # local shared hooks
        if [ -f "$(pwd)/.githooks/.shared" ]; then
            SHARED_REPOS_LIST=$(grep -E "^[^#\n\r ].*$" <"$(pwd)/.githooks/.shared")

            IFS="$IFS_NEWLINE"
            for SHARED_ITEM in $(list_hooks_in_shared_repos "$LIST_TYPE"); do
                unset IFS

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

                IFS="$IFS_NEWLINE"
            done
        fi

        # in the current repository
        if [ -d ".githooks/$LIST_TYPE" ]; then

            IFS="$IFS_NEWLINE"
            for LIST_ITEM in .githooks/"$LIST_TYPE"/*; do
                unset IFS

                ITEM_NAME=$(basename "$LIST_ITEM")
                ITEM_STATE=$(get_hook_state "$(pwd)/.githooks/$LIST_TYPE/$ITEM_NAME")
                LIST_OUTPUT="$LIST_OUTPUT
  - $ITEM_NAME (${ITEM_STATE})"

                IFS="$IFS_NEWLINE"
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
    if [ "$GITHOOKS_CONFIG_DISABLE" = "true" ] ||
        [ "$GITHOOKS_CONFIG_DISABLE" = "y" ] ||    # Legacy
        [ "$GITHOOKS_CONFIG_DISABLE" = "Y" ]; then # Legacy
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

        # shellcheck disable=SC2295
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

    # Check if global hooks are trusted
    if [ "$GLOBAL" ]; then
        TRUST_ALL_SHARED_CONFIG=$(git config --global --get githooks.trust.all)
        if [ "$TRUST_ALL_SHARED_CONFIG" = "Y" ]; then
            return 0
        else
            return 1
        fi
    fi
    
    # Check local shared hook are trusted
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

    SHA_HASH=$(get_hook_checksum "$HOOK_PATH")
    CURRENT_HASHES=$(grep "$HOOK_PATH" "${CURRENT_GIT_DIR}/.githooks.checksum" 2>/dev/null)

    # check against the previous hash
    if echo "$CURRENT_HASHES" | grep -q "disabled> $HOOK_PATH" >/dev/null 2>&1; then
        echo "disabled"
    elif ! echo "$CURRENT_HASHES" | grep -F -q "$SHA_HASH $HOOK_PATH" >/dev/null 2>&1; then
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
    SHARED_LIST_TYPE="$1"
    ALREADY_LISTED=""

    IFS="$IFS_NEWLINE"
    for SHARED_REPO_ITEM in $SHARED_REPOS_LIST; do
        unset IFS

        set_shared_root "$SHARED_REPO_ITEM"

        if [ -e "${SHARED_ROOT}/.githooks/${SHARED_LIST_TYPE}" ]; then
            echo "${SHARED_ROOT}/.githooks/${SHARED_LIST_TYPE}"
        elif [ -e "${SHARED_ROOT}/${SHARED_LIST_TYPE}" ]; then
            echo "${SHARED_ROOT}/${SHARED_LIST_TYPE}"
        fi

        ALREADY_LISTED="$ALREADY_LISTED
        ${SHARED_ROOT}"
    done

    if [ ! -d "$INSTALL_DIR/shared" ]; then
        return
    fi

    IFS="$IFS_NEWLINE"
    for SHARED_ROOT in "$INSTALL_DIR/shared/"*; do
        unset IFS
        if [ ! -d "$SHARED_ROOT" ]; then
            continue
        fi

        if echo "$ALREADY_LISTED" | grep -F -q "$SHARED_ROOT"; then
            continue
        fi

        REMOTE_URL=$(git -C "$SHARED_ROOT" config --get remote.origin.url)
        ACTIVE_REPO=$(echo "$SHARED_REPOS_LIST" | grep -F -o "$REMOTE_URL")
        if [ "$ACTIVE_REPO" != "$REMOTE_URL" ]; then
            continue
        fi

        if [ -e "${SHARED_ROOT}/.githooks/${SHARED_LIST_TYPE}" ]; then
            echo "${SHARED_ROOT}/.githooks/${SHARED_LIST_TYPE}"
        elif [ -e "${SHARED_ROOT}/${LIST_TYPE}" ]; then
            echo "${SHARED_ROOT}/${LIST_TYPE}"
        fi
        IFS="$IFS_NEWLINE"
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
git hooks shared [add|remove] [--shared|--local|--global] <git-url>
git hooks shared clear [--shared|--local|--global|--all]
git hooks shared purge
git hooks shared list [--shared|--local|--global|--all]
git hooks shared [update|pull]

    Manages the shared hook repositories set either in the \`.githooks.shared\` file locally in the repository or
    in the local or global Git configuration \`githooks.shared\`.
    The \`add\` or \`remove\` subcommands adds or removes an item, given as \`git-url\` from the list.
    If \`--local|--global\` is given, then the \`githooks.shared\` local/global Git configuration
    is modified, or if the \`--shared\` option (default) is set, the \`.githooks/.shared\`
    file is modified in the local repository.
    The \`clear\` subcommand deletes every item on either the global or the local list,
    or both when the \`--all\` option is given.
    The \`purge\` subcommand deletes the shared hook repositories already pulled locally.
    The \`list\` subcommand list the shared, local, global or all (default) shared hooks repositories.
    The \`update\` or \`pull\` subcommands update all the shared repositories, either by
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
    SET_SHARED_TYPE="--shared"
    SHARED_REPO_URL=

    if echo "$1" | grep -qE "\-\-(shared|local|global)"; then
        SET_SHARED_TYPE="$1"
        SHARED_REPO_URL="$2"
    else
        SHARED_REPO_URL="$1"
    fi

    if [ -z "$SHARED_REPO_URL" ]; then
        echo "! Usage: \`git hooks shared add [--shared|--local|--global] <git-url>\`" >&2
        exit 1
    fi

    if [ "$SET_SHARED_TYPE" != "--shared" ]; then

        if [ "$SET_SHARED_TYPE" = "--local" ] && ! is_running_in_git_repo_root; then
            echo "! The current directory \`$(pwd)\` does not" >&2
            echo "  seem to be the root of a Git repository!" >&2
            exit 1
        fi

        git config "$SET_SHARED_TYPE" --add githooks.shared "$SHARED_REPO_URL" &&
            echo "The new shared hook repository is successfully added" &&
            if [ "$SET_SHARED_TYPE" = "--global" ]; then add_trusted_repo "$@"; fi &&
        return
    
        echo "! Failed to add the new shared hook repository" >&2
        exit 1
      
    else
        if ! is_running_in_git_repo_root; then
            echo "! The current directory \`$(pwd)\` does not" >&2
            echo "  seem to be the root of a Git repository!" >&2
            exit 1
        fi

        if is_local_path "$SHARED_REPO_URL" ||
            is_local_url "$SHARED_REPO_URL"; then
            echo "! Adding a local path:" >&2
            echo "  \`$SHARED_REPO_URL\`" >&2
            echo "  to the local shared hooks is forbidden." >&2
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

add_trusted_repo(){
    GLOBAL_TRUST=$(git config --global --get githooks.trust.all)
    if [ "${GLOBAL_TRUST}" = "" ] || [ "${GLOBAL_TRUST}" = "N" ]; then

        printf "If a trust marker is found in this repository, do you want to trust and accept future hooks without prompting ? [y/N]"
        read -r TRUST_ALL_HOOKS </dev/tty
        if [ "$TRUST_ALL_HOOKS" = "y" ] || [ "$TRUST_ALL_HOOKS" = "Y" ]; then
            git config --global githooks.trust.all Y
        else
            git config --global githooks.trust.all N
        fi
    fi
}
#####################################################
# Removes the URL of a new shared hook repository to
#   the global or local list.
#####################################################
remove_shared_hook_repo() {
    SET_SHARED_TYPE="--shared"
    SHARED_REPO_URL=

    if echo "$1" | grep -qE "\-\-(shared|local|global)"; then
        SET_SHARED_TYPE="$1"
        SHARED_REPO_URL="$2"
    else
        SHARED_REPO_URL="$1"
    fi

    if [ -z "$SHARED_REPO_URL" ]; then
        echo "! Usage: \`git hooks shared remove [--shared|--local|--global] <git-url>\`" >&2
        exit 1
    fi

    if [ "$SET_SHARED_TYPE" != "--shared" ]; then

        if [ "$SET_SHARED_TYPE" = "--local" ] && ! is_running_in_git_repo_root; then
            echo "! The current directory \`$(pwd)\` does not" >&2
            echo "  seem to be the root of a Git repository!" >&2
            exit 1
        fi

        CURRENT_LIST=$(git config "$SET_SHARED_TYPE" --get-all githooks.shared)

        # Unset all and add them back
        git config "$SET_SHARED_TYPE" --unset-all githooks.shared

        IFS="$IFS_NEWLINE"
        for SHARED_REPO_ITEM in $CURRENT_LIST; do
            unset IFS
            if [ "$SHARED_REPO_ITEM" = "$SHARED_REPO_URL" ]; then
                continue
            fi

            git config "$SET_SHARED_TYPE" --add githooks.shared "$SHARED_REPO_ITEM"
            IFS="$IFS_NEWLINE"
        done
        unset IFS

        echo "The list of shared hook repositories is successfully changed"
        return

    else
        if ! is_running_in_git_repo_root; then
            echo "The current directory \`$(pwd)\` does not seem to be the root of a Git repository!"
            exit 1
        fi

        if [ ! -f "$(pwd)/.githooks/.shared" ]; then
            echo "! No \`.githooks/.shared\` in current repository" >&2
            return
        fi

        NEW_LIST=""
        ONLY_COMMENTS="true"
        IFS="$IFS_NEWLINE"
        while read -r LINE || [ -n "$LINE" ]; do
            unset IFS

            if echo "$LINE" | grep -qE "^[^#\n\r ].*$"; then
                if [ "$LINE" = "$SHARED_REPO_URL" ]; then
                    continue
                fi
                ONLY_COMMENTS="false"
            elif echo "$LINE" | grep -qE "^ *[#].*$"; then
                : # nothing to do for comments ...
            else
                : # skip empty lines
            fi

            if [ -z "$NEW_LIST" ]; then
                NEW_LIST="$LINE"
            else
                NEW_LIST="${NEW_LIST}
${LINE}"
            fi

            IFS="$IFS_NEWLINE"
        done <"$(pwd)/.githooks/.shared"
        unset IFS

        if [ -z "$NEW_LIST" ] || [ "$ONLY_COMMENTS" = "true" ]; then
            clear_shared_hook_repos "$SET_SHARED_TYPE" && return || exit 1
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
    CLEAR_GLOBAL_REPOS=""
    CLEAR_LOCAL_REPOS=""
    CLEAR_SHARED_REPOS=""
    CLEAR_REPOS_FAILED=""

    case "$1" in
    "--shared")
        CLEAR_SHARED_REPOS=1
        ;;
    "--local")
        CLEAR_LOCAL_REPOS=1
        ;;
    "--global")
        CLEAR_GLOBAL_REPOS=1
        ;;
    "--all")
        CLEAR_SHARED_REPOS=1
        CLEAR_LOCAL_REPOS=1
        CLEAR_GLOBAL_REPOS=1
        ;;
    *)
        echo "! Unknown clear option \`$1\`" >&2
        echo "  Usage: \`git hooks shared clear [--shared|--local|--global|--all]\`" >&2
        exit 1
        ;;
    esac

    if [ -n "$CLEAR_LOCAL_REPOS" ]; then
        if ! is_running_in_git_repo_root; then
            echo "! The current directory \`$(pwd)\` does not" >&2
            echo "  seem to be the root of a Git repository!" >&2
            CLEAR_REPOS_FAILED=1
        else
            git config --local --unset-all githooks.shared
            echo "Shared hook repository list in local Git config cleared"
        fi
    fi

    if [ -n "$CLEAR_GLOBAL_REPOS" ]; then
        git config --global --unset-all githooks.shared
        echo "Shared hook repository list in global Git config cleared"
    fi

    if [ -n "$CLEAR_SHARED_REPOS" ] && [ -f "$(pwd)/.githooks/.shared" ]; then
        rm -f "$(pwd)/.githooks/.shared" &&
            echo "Shared hook repository list in \".githooks/.shared\` file cleared" ||
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
    LIST_SHARED=1
    LIST_CONFIGS="global,local"

    for ARG in "$@"; do
        case "$ARG" in
        "--shared")
            LIST_CONFIGS=""
            ;;
        "--local")
            LIST_CONFIGS="local"
            LIST_SHARED=""
            ;;
        "--global")
            LIST_CONFIGS="global"
            LIST_SHARED=""
            ;;
        "--all") ;;
        *)
            echo "! Unknown list option \`$ARG\`" >&2
            echo "  Usage: \`git hooks shared list [--shared|--local|--global|--all]\`" >&2
            exit 1
            ;;
        esac
    done

    IFS=","
    for LIST_CONFIG in $LIST_CONFIGS; do
        unset IFS

        echo "Shared hook repositories in $LIST_CONFIG Git config:"
        SHARED_REPOS_LIST=$(git config "--$LIST_CONFIG" --get-all githooks.shared)

        if [ -z "$SHARED_REPOS_LIST" ]; then
            echo "  - None"
        else

            IFS="$IFS_NEWLINE"
            for LIST_ITEM in $SHARED_REPOS_LIST; do
                unset IFS

                set_shared_root "$LIST_ITEM"

                LIST_ITEM_STATE="invalid"

                if [ "$SHARED_REPO_IS_CLONED" = "true" ]; then
                    if [ -d "$SHARED_ROOT" ]; then
                        if [ "$(git -C "$SHARED_ROOT" config --get remote.origin.url)" = "$SHARED_REPO_CLONE_URL" ]; then
                            LIST_ITEM_STATE="active"
                        fi
                    else
                        LIST_ITEM_STATE="pending"
                    fi
                else
                    [ -d "$SHARED_ROOT" ] && LIST_ITEM_STATE="active"
                fi

                echo "  - $LIST_ITEM ($LIST_ITEM_STATE)"

                IFS="$IFS_NEWLINE"
            done
            unset IFS
        fi

        IFS=","
    done
    unset IFS

    if [ -n "$LIST_SHARED" ]; then
        echo "Shared hook repositories in \`.githooks/.shared\`:"

        if ! is_running_in_git_repo_root; then
            echo "  - Current folder does not seem to be a Git repository"
            [ -z "$LIST_CONFIGS" ] && exit 1
        elif [ ! -f "$(pwd)/.githooks/.shared" ]; then
            echo "  - None"
        else
            SHARED_REPOS_LIST=$(grep -E "^[^#\n\r ].*$" <"$(pwd)/.githooks/.shared")

            IFS="$IFS_NEWLINE"
            for LIST_ITEM in $SHARED_REPOS_LIST; do
                unset IFS

                set_shared_root "$LIST_ITEM"

                LIST_ITEM_STATE="invalid"

                if [ "$SHARED_REPO_IS_CLONED" != "true" ]; then
                    [ -d "$SHARED_ROOT" ] && LIST_ITEM_STATE="active"
                else
                    if [ -d "$SHARED_ROOT" ]; then
                        if [ "$(git -C "$SHARED_ROOT" config --get remote.origin.url)" = "$SHARED_REPO_CLONE_URL" ]; then
                            LIST_ITEM_STATE="active"
                        fi
                    else
                        LIST_ITEM_STATE="pending"
                    fi
                fi

                echo "  - $LIST_ITEM ($LIST_ITEM_STATE)"

                IFS="$IFS_NEWLINE"
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
git hooks shared pull

    Updates the shared repositories found either
    in the global Git configuration, or in the
    \`.githooks/.shared\` file in the local repository.

> Please use \`git hooks shared pull\` instead, this version is now deprecated.
"
        return
    fi

    if [ -f "$(pwd)/.githooks/.shared" ]; then
        SHARED_HOOKS=$(grep -E "^[^#\n\r ].*$" <"$(pwd)/.githooks/.shared")
        update_shared_hooks_in --shared "$SHARED_HOOKS"
    fi

    SHARED_HOOKS=$(git config --local --get-all githooks.shared 2>/dev/null)
    if [ -n "$SHARED_HOOKS" ]; then
        update_shared_hooks_in --local "$SHARED_HOOKS"
    fi

    SHARED_HOOKS=$(git config --global --get-all githooks.shared)
    if [ -n "$SHARED_HOOKS" ]; then
        update_shared_hooks_in --global "$SHARED_HOOKS"
    fi

    echo "Finished"
}

#####################################################
# Check if `$1` is not a supported git clone url and
#   is treated as a local path to a repository.
#   See `https://tools.ietf.org/html/rfc3986#appendix-B`

# Returns: 0 if it is a local path, 1 otherwise
#####################################################
is_local_path() {
    if echo "$1" | grep -Eq "^[^:/?#]+://" ||  # its a URL `<scheme>://...``
        echo "$1" | grep -Eq "^.+@.+:.+"; then # or its a short scp syntax
        return 1
    fi
    return 0
}

#####################################################
# Check if url `$1`is a local url, e.g `file://`.
#
# Returns: 0 if it is a local url, 1 otherwise
#####################################################
is_local_url() {
    if echo "$1" | grep -iEq "^\s*file://"; then
        return 0
    fi
    return 1
}

#####################################################
# Sets the `SHARED_ROOT` and `NORMALIZED_NAME`
#   for the shared hook repo url `$1` and sets
#   `SHARED_REPO_IS_CLONED` to `true` and its
#   `SHARED_REPO_CLONE_URL` if is needs to get
#    cloned and `SHARED_REPO_IS_LOCAL` to `true`
#    if `$1` points to to a local path.
#
# Returns:
#   none
#####################################################
set_shared_root() {

    SHARED_ROOT=""
    SHARED_REPO_CLONE_URL=""
    SHARED_REPO_CLONE_BRANCH=""
    SHARED_REPO_IS_LOCAL="false"
    SHARED_REPO_IS_CLONED="true"
    DO_SPLIT="true"

    if is_local_path "$1"; then
        SHARED_REPO_IS_LOCAL="true"

        if is_bare_repo "$1"; then
            DO_SPLIT="false"
        else
            # We have a local path to a non-bare repo
            SHARED_REPO_IS_CLONED="false"
            SHARED_ROOT="$1"
            return
        fi
    elif is_local_url "$1"; then
        SHARED_REPO_IS_LOCAL="true"
    fi

    if [ "$SHARED_REPO_IS_CLONED" = "true" ]; then
        # Here we now have a supported Git URL or
        # a local bare-repo `<localpath>`

        # Split "...@(.*)"
        if [ "$DO_SPLIT" = "true" ] && echo "$1" | grep -q "@"; then
            SHARED_REPO_CLONE_URL="$(echo "$1" | sed -E "s|^(.+)@.+$|\\1|")"
            SHARED_REPO_CLONE_BRANCH="$(echo "$1" | sed -E "s|^.+@(.+)$|\\1|")"
        else
            SHARED_REPO_CLONE_URL="$1"
            SHARED_REPO_CLONE_BRANCH=""
        fi

        # Double-check what we did above
        if echo "$SHARED_REPO_CLONE_BRANCH" | grep -q ":"; then
            # the branch name had a ":" so it was probably not a branch name
            SHARED_REPO_CLONE_URL="${SHARED_REPO_CLONE_URL}@${SHARED_REPO_CLONE_BRANCH}"
            SHARED_REPO_CLONE_BRANCH=""

        elif echo "$SHARED_REPO_CLONE_URL" | grep -qE ".*://[^/]+$"; then
            # the clone URL is something starting with a protocol then no path parts, then we probably split at the wrong place
            SHARED_REPO_CLONE_URL="${SHARED_REPO_CLONE_URL}@${SHARED_REPO_CLONE_BRANCH}"
            SHARED_REPO_CLONE_BRANCH=""
        fi

        # Define the shared clone folder
        SHA_HASH=$(echo "$1" | git hash-object --stdin 2>/dev/null)
        NAME=$(echo "$1" | tail -c 48 | sed -E "s/[^a-zA-Z0-9]/-/g")
        SHARED_ROOT="$INSTALL_DIR/shared/$SHA_HASH-$NAME"
    fi
}

#####################################################
# Updates the shared hooks repositories
#   on the list passed in on the first argument.
#####################################################
update_shared_hooks_in() {
    SHARED_HOOKS_TYPE="$1"
    SHARED_REPOS_LIST="$2"

    IFS="$IFS_NEWLINE"
    for SHARED_REPO in $SHARED_REPOS_LIST; do
        unset IFS

        set_shared_root "$SHARED_REPO"

        if [ "$SHARED_REPO_IS_CLONED" != "true" ]; then
            # Non-cloned roots are ignored
            continue
        elif [ "$SHARED_HOOKS_TYPE" = "--shared" ] &&
            [ "$SHARED_REPO_IS_LOCAL" = "true" ]; then
            echo "! Warning: Shared hooks in \`.githooks/.shared\` contain a local path" >&2
            echo "  \`$SHARED_REPO\`" >&2
            echo "  which is forbidden. It will be skipped." >&2
            echo ""
            echo "  You can only have local paths for shared hooks defined" >&2
            echo "  in the local or global Git configuration." >&2
            echo ""
            echo "  This can be achieved by running" >&2
            echo "    \$ git hooks shared add [--local|--global] \"$SHARED_REPO\"" >&2
            echo "  and deleting it from the \`.shared\` file by" >&2
            echo "    \$ git hooks shared remove --shared \"$SHARED_REPO\"" >&2
            continue
        fi

        if [ -d "$SHARED_ROOT/.git" ]; then
            echo "* Updating shared hooks from: $SHARED_REPO"

            # shellcheck disable=SC2086
            PULL_OUTPUT="$(execute_git "$SHARED_ROOT" pull 2>&1)"

            # shellcheck disable=SC2181
            if [ $? -ne 0 ]; then
                echo "! Update failed, git pull output:" >&2
                echo "$PULL_OUTPUT" >&2
            fi
        else
            echo "* Retrieving shared hooks from: $SHARED_REPO_CLONE_URL"

            ADD_ARGS=""
            [ "$SHARED_REPO_IS_LOCAL" != "true" ] && ADD_ARGS="--depth=1"

            [ -d "$SHARED_ROOT" ] &&
                rm -rf "$SHARED_ROOT" &&
                mkdir -p "$SHARED_ROOT"

            if [ -n "$SHARED_REPO_CLONE_BRANCH" ]; then
                # shellcheck disable=SC2086
                CLONE_OUTPUT=$(git clone \
                    -c core.hooksPath=/dev/null \
                    --template=/dev/null \
                    --single-branch \
                    --branch "$SHARED_REPO_CLONE_BRANCH" \
                    $ADD_ARGS \
                    "$SHARED_REPO_CLONE_URL" \
                    "$SHARED_ROOT" 2>&1)
            else
                # shellcheck disable=SC2086
                CLONE_OUTPUT=$(git clone \
                    -c core.hooksPath=/dev/null \
                    --template=/dev/null \
                    --single-branch \
                    $ADD_ARGS \
                    "$SHARED_REPO_CLONE_URL" \
                    "$SHARED_ROOT" 2>&1)
            fi

            # shellcheck disable=SC2181
            if [ $? -ne 0 ]; then
                echo "! Clone failed, git clone output:" >&2
                echo "$CLONE_OUTPUT" >&2
            fi
        fi

        IFS="$IFS_NEWLINE"
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

    INSTALL_FLAGS="--single"
    if [ "$1" = "--global" ]; then
        INSTALL_FLAGS=""
    elif [ -n "$1" ]; then
        echo "! Invalid argument: \`$1\`" >&2 && exit 1
    fi

    if ! fetch_latest_updates; then
        echo "! Failed to fetch the latest install script" >&2
        echo "  You can retry manually using one of the alternative methods," >&2
        echo "  see them here: https://github.com/rycus86/githooks#installation" >&2
        exit 1
    fi

    # shellcheck disable=SC2086
    if ! execute_install_script $INSTALL_FLAGS; then
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

    UNINSTALL_ARGS="--single"
    if [ "$1" = "--global" ]; then
        UNINSTALL_ARGS="--global"
    elif [ -n "$1" ]; then
        echo "! Invalid argument: \`$1\`" >&2 && exit 1
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
        return 0
    fi

    if [ "$1" = "enable" ]; then
        git config --global githooks.autoupdate.enabled true &&
            echo "Automatic update checks have been enabled" &&
            return 0

        echo "! Failed to enable automatic updates" >&2 && exit 1

    elif [ "$1" = "disable" ]; then
        git config --global githooks.autoupdate.enabled false &&
            echo "Automatic update checks have been disabled" &&
            return 0

        echo "! Failed to disable automatic updates" >&2 && exit 1

    elif [ -n "$1" ] && [ "$1" != "force" ]; then
        echo "! Invalid operation: \`$1\`" >&2 && exit 1

    fi

    record_update_time

    if ! fetch_latest_updates; then
        echo "! Failed to check for updates: cannot fetch updates"
        exit 1
    fi

    if [ "$1" != "force" ]; then
        if ! is_update_available; then
            echo "  Githooks is already on the latest version"
            return 0
        fi
    fi

    # shellcheck disable=SC2086
    if ! execute_install_script $INSTALL_FLAGS; then
        echo "! Failed to execute the installation"
        print_update_disable_info
        return 1
    fi
    return 0
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
# Does a update clone repository exist in the
#  install folder
#
# Returns: 0 if `true`, 1 otherwise
#####################################################
is_release_clone_existing() {
    if git -C "$INSTALL_DIR/release" rev-parse >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

#####################################################
# Checks if there is an update in the release clone
#   waiting for a fast-forward merge.
#
# Returns:
#   0 if an update needs to be applied, 1 otherwise
#####################################################
is_update_available() {
    [ "$GITHOOKS_CLONE_UPDATE_AVAILABLE" = "true" ] || return 1
}

#####################################################
# Fetches updates in the release clone.
#   If the release clone is newly created the variable
#   `$GITHOOKS_CLONE_CREATED` is set to
#   `true`
#   If an update is available
#   `GITHOOKS_CLONE_UPDATE_AVAILABLE` is set to `true`
#
# Returns:
#   1 if failed, 0 otherwise
#####################################################
fetch_latest_updates() {

    echo "^ Checking for updates ..."

    GITHOOKS_CLONE_CREATED="false"
    GITHOOKS_CLONE_UPDATE_AVAILABLE="false"

    GITHOOKS_CLONE_URL=$(git config --global githooks.cloneUrl)
    GITHOOKS_CLONE_BRANCH=$(git config --global githooks.cloneBranch)

    # We do a fresh clone if there is not a repository
    # or wrong url/branch configured and the user agrees.
    if is_git_repo "$GITHOOKS_CLONE_DIR"; then

        URL=$(execute_git "$GITHOOKS_CLONE_DIR" config remote.origin.url 2>/dev/null)
        BRANCH=$(execute_git "$GITHOOKS_CLONE_DIR" symbolic-ref -q --short HEAD 2>/dev/null)

        if [ "$URL" != "$GITHOOKS_CLONE_URL" ] ||
            [ "$BRANCH" != "$GITHOOKS_CLONE_BRANCH" ]; then

            CREATE_NEW_CLONE="false"

            echo "! Cannot fetch updates because \`origin\` of update clone" >&2
            echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
            echo "  points to url:" >&2
            echo "  \`$URL\`" >&2
            echo "  on branch \`$BRANCH\`" >&2
            echo "  which is not configured." >&2

            echo "Do you want to delete and reclone the existing update clone? [N/y]"
            read -r ANSWER </dev/tty

            if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
                CREATE_NEW_CLONE="true"
            fi

            if [ "$CREATE_NEW_CLONE" != "true" ]; then
                echo "! See \`git hooks config [set|print] clone-url\` and" >&2
                echo "      \`git hooks config [set|print] clone-branch\`" >&2
                echo "  Either fix this or delete the clone" >&2
                echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
                echo "  to trigger a new checkout." >&2
                return 1
            fi
        fi

        # Check if the update clone is dirty which it really should not.
        if ! execute_git "$GITHOOKS_CLONE_DIR" diff-index --quiet HEAD >/dev/null 2>&1; then
            echo "! Cannot pull updates because the update clone" >&2
            echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
            echo "  is dirty!" >&2

            echo "Do you want to delete and reclone the existing update clone? [N/y]"
            read -r ANSWER </dev/tty

            if [ "$ANSWER" = "y" ] || [ "$ANSWER" = "Y" ]; then
                CREATE_NEW_CLONE="true"
            fi

            if [ "$CREATE_NEW_CLONE" != "true" ]; then
                echo "! Either fix this or delete the clone" >&2
                echo "  \`$GITHOOKS_CLONE_DIR\`" >&2
                echo "  to trigger a new checkout." >&2
                return 1
            fi
        fi
    else
        CREATE_NEW_CLONE="true"
    fi

    if [ "$CREATE_NEW_CLONE" = "true" ]; then
        clone_release_repository || return 1

        # shellcheck disable=SC2034
        GITHOOKS_CLONE_CREATED="true"
        GITHOOKS_CLONE_UPDATE_AVAILABLE="true"
    else

        FETCH_OUTPUT=$(
            execute_git "$GITHOOKS_CLONE_DIR" fetch origin "$GITHOOKS_CLONE_BRANCH" 2>&1
        )

        # shellcheck disable=SC2181
        if [ $? -ne 0 ]; then
            echo "! Fetching updates in  \`$GITHOOKS_CLONE_DIR\` failed with:" >&2
            echo "$FETCH_OUTPUT" >&2
            return 1
        fi

        RELEASE_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse "$GITHOOKS_CLONE_BRANCH")
        UPDATE_COMMIT=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse "origin/$GITHOOKS_CLONE_BRANCH")

        if [ "$RELEASE_COMMIT" != "$UPDATE_COMMIT" ]; then
            # We have an update available
            # install.sh deals with updating ...
            GITHOOKS_CLONE_UPDATE_AVAILABLE="true"
        fi
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
# Checks whether the given directory
#   is a Git bare repository.
#
# Returns:
#   1 if failed, 0 otherwise
############################################################
is_bare_repo() {
    [ "$(git -C "$1" rev-parse --is-bare-repository 2>/dev/null)" = "true" ] || return 1
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
#  Creates the release clone if needed.
# Returns:
#   1 if failed, 0 otherwise
#####################################################
assert_release_clone() {

    # We do a fresh clone if there is no clone
    if ! is_git_repo "$GITHOOKS_CLONE_DIR"; then
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

    GITHOOKS_CLONE_URL=$(git config --global githooks.cloneUrl)
    GITHOOKS_CLONE_BRANCH=$(git config --global githooks.cloneBranch)

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

    CLONE_OUTPUT=$(git clone \
        -c core.hooksPath=/dev/null \
        --template=/dev/null \
        --depth=1 \
        --single-branch \
        --branch "$GITHOOKS_CLONE_BRANCH" \
        "$GITHOOKS_CLONE_URL" "$GITHOOKS_CLONE_DIR" 2>&1)

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

#####################################################
# Checks if updates are enabled.
#
# Returns:
#   0 if updates are enabled, 1 otherwise
#####################################################
is_autoupdate_enabled() {
    [ "$(git config --global githooks.autoupdate.enabled)" = "Y" ] || return 1
}

#####################################################
# Performs the installation of the previously
#   fetched install script.
#
# Returns:
#   0 if the installation was successful, 1 otherwise
#####################################################
execute_install_script() {

    if ! assert_release_clone; then
        echo "! Could not create a release clone in \`$GITHOOKS_CLONE_DIR\`" >&2
        exit 1
    fi

    # Set the install script
    INSTALL_SCRIPT="$INSTALL_DIR/release/install.sh"
    if [ ! -f "$INSTALL_SCRIPT" ]; then
        echo "! Non-existing \`install.sh\` in  \`$INSTALL_DIR/release\`" >&2
        return 1
    fi

    sh -s -- "$@" <"$INSTALL_SCRIPT" || return 1
    return 0
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

    # Set the install script
    UNINSTALL_SCRIPT="$INSTALL_DIR/release/uninstall.sh"
    if [ ! -f "$UNINSTALL_SCRIPT" ]; then
        echo "! Non-existing \`uninstall.sh\` in  \`$INSTALL_DIR/release\`" >&2
        return 1
    fi

    sh -s -- "$@" <"$UNINSTALL_SCRIPT" || return 1

    return 0
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
        echo "The current directory \`$(pwd)\` does not seem to be the root of a Git repository!"
        exit 1
    fi

    if [ -f .githooks/README.md ] && [ "$FORCE_README" != "y" ]; then
        echo "! This repository already seems to have a Githooks README." >&2
        echo "  If you would like to replace it with the latest one, please run \`git hooks readme update\`" >&2
        exit 1
    fi

    if ! assert_release_clone; then
        exit 1
    fi

    README_FILE="$INSTALL_DIR/release/.githooks/README.md"
    mkdir -p "$(pwd)/.githooks" &&
        cat "$README_FILE" >"$(pwd)/.githooks/README.md" &&
        echo "The README file is updated." &&
        echo_if_non_bare_repo "  Do not forget to commit and push it!" ||
        echo "! Failed to update the README file in the current repository" >&2
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
        echo "The current directory \`$(pwd)\` does not seem to be the root of a Git repository!"
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
git hooks config list [--local|--global]

    Lists the Githooks related settings of the Githooks configuration.
    Can be either global or local configuration, or both by default.

git hooks config [set|reset|print] disable

    Disables running any Githooks files in the current repository,
    when the \`set\` option is used.
    The \`reset\` option clears this setting.
    The \`print\` option outputs the current setting.
    This command needs to be run at the root of a repository.

[deprecated] git hooks config [set|reset|print] single

    This command is deprecated and will be removed in the future.
    Marks the current local repository to be managed as a single Githooks
    installation, or clears the marker, with \`set\` and \`reset\` respectively.
    The \`print\` option outputs the current setting of it.
    This command needs to be run at the root of a repository.

git hooks config set search-dir <path>
git hooks config [reset|print] search-dir

    Changes the previous search directory setting used during installation.
    The \`set\` option changes the value, and the \`reset\` option clears it.
    The \`print\` option outputs the current setting of it.

git hooks config set shared [--local] <git-url...>
git hooks config [reset|print] shared [--local]

    Updates the list of global (or local) shared hook repositories when
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

git hooks config set clone-url <git-url>
git hooks config [set|print] clone-url

    Sets or prints the configured githooks clone url used
    for any update.

git hooks config set clone-branch <branch-name>
git hooks config print clone-branch

    Sets or prints the configured branch of the update clone
    used for any update.

git hooks config [reset|print] update-time

    Resets the last Githooks update time with the \`reset\` option,
    causing the update check to run next time if it is enabled.
    Use \`git hooks update [enable|disable]\` to change that setting.
    The \`print\` option outputs the current value of it.

git hooks config [enable|disable|print] fail-on-non-existing-shared-hooks [--local|--global]

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

    [ "$#" -ge 1 ] && shift
    [ "$#" -ge 1 ] && shift

    case "$CONFIG_ARGUMENT" in
    "disable")
        config_disable "$CONFIG_OPERATION"
        ;;
    "search-dir")
        config_search_dir "$CONFIG_OPERATION" "$@"
        ;;
    "shared")
        config_shared_hook_repos "$CONFIG_OPERATION" "$@"
        ;;
    "trusted")
        config_trust_all_hooks "$CONFIG_OPERATION"
        ;;
    "update")
        config_update_state "$CONFIG_OPERATION" "$@"
        ;;
    "clone-url")
        config_update_clone_url "$CONFIG_OPERATION" "$@"
        ;;
    "clone-branch")
        config_update_clone_branch "$CONFIG_OPERATION" "$@"
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
        echo "The current directory \`$(pwd)\` does not seem to be the root of a Git repository!"
        exit 1
    fi

    if [ "$1" = "set" ]; then
        git config githooks.disable true
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
# Manages previous search directory setting
#   used during Githooks installation.
# Prints or modifies the
#   \`githooks.previousSearchDir\`
#   global Git configuration.
#####################################################
config_search_dir() {
    if [ "$1" = "set" ]; then
        if [ -z "$2" ]; then
            manage_configuration "help"
            echo "! Missing <path> parameter" >&2
            exit 1
        fi

        git config --global githooks.previousSearchDir "$2"
    elif [ "$1" = "reset" ]; then
        git config --global --unset githooks.previousSearchDir
    elif [ "$1" = "print" ]; then
        CONFIG_SEARCH_DIR=$(git config --global --get githooks.previousSearchDir)
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
config_shared_hook_repos() {

    if [ "$1" = "set" ]; then

        SHARED_TYPE="--global"
        [ "$2" = "--local" ] && SHARED_TYPE="$2" && shift

        if [ -z "$2" ]; then
            manage_configuration "help"
            echo "! Missing <git-url> parameter" >&2
            exit 1
        fi

        shift

        for SHARED_REPO_ITEM in "$@"; do
            git config "$SHARED_TYPE" --add githooks.shared "$SHARED_REPO_ITEM"
        done

    elif [ "$1" = "reset" ]; then
        SHARED_TYPE="--global"
        if echo "$2" | grep -qE "\-\-(local)"; then
            SHARED_TYPE="$2"
        elif [ -n "$2" ]; then
            manage_configuration "help"
            echo "! Wrong argument \`$2\`" >&2
        fi

        git config "$SHARED_TYPE" --unset-all githooks.shared

    elif [ "$1" = "print" ]; then
        SHARED_TYPE="--global"
        if echo "$2" | grep -qE "\-\-(local)"; then
            SHARED_TYPE="$2"
        elif [ -n "$2" ]; then
            manage_configuration "help"
            echo "! Wrong argument $($2)" >&2
        fi
        list_shared_hook_repos "$SHARED_TYPE"
    else
        manage_configuration "help"
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
        echo "The current directory \`$(pwd)\` does not seem to be the root of a Git repository!"
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
        git config --global githooks.autoupdate.enabled true
    elif [ "$1" = "disable" ]; then
        git config --global githooks.autoupdate.enabled false
    elif [ "$1" = "reset" ]; then
        git config --global --unset githooks.autoupdate.enabled
    elif [ "$1" = "print" ]; then
        CONFIG_UPDATE_ENABLED=$(git config --get githooks.autoupdate.enabled)
        if [ "$CONFIG_UPDATE_ENABLED" = "true" ] ||
            [ "$CONFIG_UPDATE_ENABLED" = "Y" ]; then
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
# Manages the automatic update clone url.
# Prints or modifies the
#   \`githooks.cloneUrl\`
#   global Git configuration.
#####################################################
config_update_clone_url() {
    if [ "$1" = "print" ]; then
        echo "Update clone url set to: $(git config --global githooks.cloneUrl)"
    elif [ "$1" = "set" ]; then
        if [ -z "$2" ]; then
            echo "! No valid url given" >&2
            exit 1
        fi
        git config --global githooks.cloneUrl "$2"
        config_update_clone_url "print"
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, or \`print\`)" >&2
        exit 1
    fi
}

#####################################################
# Manages the automatic update clone branch.
# Prints or modifies the
#   \`githooks.cloneUrl\`
#   global Git configuration.
#####################################################
config_update_clone_branch() {
    if [ "$1" = "print" ]; then
        echo "Update clone branch set to: $(git config --global githooks.cloneBranch)"
    elif [ "$1" = "set" ]; then
        if [ -z "$2" ]; then
            echo "! No valid branch name given" >&2
            exit 1
        fi
        git config --global githooks.cloneBranch "$2"
        config_update_clone_branch "print"
    else
        echo "! Invalid operation: \`$1\` (use \`set\`, or \`print\`)" >&2
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
git hooks tools register <toolName> <scriptFolder>

    Install the script folder \`<scriptFolder>\` in
    the installation directory under \`tools/<toolName>\`.

    Currently the following tools are supported:

    >> Dialog Tool (<toolName> = \"dialog\")

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

git hooks tools unregister <toolName>

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
    if [ "$1" = "dialog" ]; then
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
        echo "! Invalid operation: \`$1\` (use \`dialog\`)" >&2
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

    if [ "$1" = "dialog" ]; then
        if [ -d "$INSTALL_DIR/tools/$1" ]; then
            rm -r "$INSTALL_DIR/tools/$1"
            [ -n "$QUIET" ] || echo "Uninstalled the \`$1\` tool"
        else
            [ -n "$QUIET" ] || echo "! The \`$1\` tool is not installed" >&2
        fi
    else
        [ -n "$QUIET" ] || echo "! Invalid tool: \`$1\` (use \`dialog\`)" >&2
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

    CURRENT_VERSION=$(execute_git "$GITHOOKS_CLONE_DIR" rev-parse --short=6 HEAD)
    CURRENT_COMMIT_DATE=$(execute_git "$GITHOOKS_CLONE_DIR" log -1 "--date=format:%y%m.%d%H%M" --format="%cd" HEAD)
    CURRENT_COMMIT_LOG=$(execute_git "$GITHOOKS_CLONE_DIR" log --pretty="format:%h (%s, %ad)" --date=short -1)
    print_help_header

    echo
    echo "Version: $CURRENT_COMMIT_DATE-$CURRENT_VERSION"
    echo "Commit: $CURRENT_COMMIT_LOG"
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
    "exec")
        execute_hook "$@"
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
