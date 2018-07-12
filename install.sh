#!/bin/sh
#
# Installs the base Git hook templates from https://github.com/rycus86/githooks
#   and performs some optional setup for existing repositories.
#   See the documentation in the project README for more information.

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
# Returns:
#   the path to the directory, or None if not found
############################################################
find_git_hook_templates() {
	if [ -d "$GIT_TEMPLATE_DIR" ]; then
		TARGET_TEMPLATE_DIR="${GIT_TEMPLATE_DIR}/hooks"
		return
	fi

	FROM_CONFIG=$(git config --get init.templateDir)
	if [ -d "$FROM_CONFIG" ]; then
		TARGET_TEMPLATE_DIR="${FROM_CONFIG}/hooks"
		return
	fi

	if [ -d /usr/share/git-core/templates/hooks ]; then
		TARGET_TEMPLATE_DIR="/usr/share/git-core/templates/hooks"
		return
	fi

	printf 'Could not find the Git hook template directory, do you want to search for it? [yN] '
	read -r DO_SEARCH

	if [ "${DO_SEARCH}" = "y" ] || [ "${DO_SEARCH}" = "Y" ]; then
		if [ -d "/usr" ]; then
			echo "Searching for potential locations in /usr ..."
			for HIT in $(find /usr 2>/dev/null | grep "templates/hooks/pre-commit.sample"); do
				HIT=$(dirname "$HIT")

				printf -- "- Is it %s ? [yN] " "$HIT"
				read -r ACCEPT

				if [ "$ACCEPT" = "y" ] || [ "$ACCEPT" = "Y" ]; then
					TARGET_TEMPLATE_DIR="$HIT"
					return
				fi
			done

			printf "Git hook template directory not found in /usr. Do you want to keep searching? [yN] "
			read -r DO_SEARCH

			if [ "${DO_SEARCH}" != "y" ] && [ "${DO_SEARCH}" != "Y" ]; then
				return
			fi
		fi

		echo "Searching for potential locations ..."
		for HIT in $(find / 2>/dev/null | grep "templates/hooks/pre-commit.sample"); do
			HIT=$(dirname "$HIT")

			printf -- "- Is it %s ? [yN] " "$HIT"
			read -r ACCEPT

			if [ "$ACCEPT" = "y" ] || [ "$ACCEPT" = "Y" ]; then
				TARGET_TEMPLATE_DIR="$HIT"
				return
			fi
		done
	fi
}

############################################################
# Install the new Git hook templates into the
#   ${TARGET_TEMPLATE_DIR} directory that we
#   have found previously.
#
# Returns:
#   None
############################################################
setup_hook_templates() {
	# shellcheck disable=SC2016
	CONTENT='#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.

execute_hook() {
    HOOK_PATH="$1"
    shift

    RESULT=0

    if [ -x "$HOOK_PATH" ]; then
        "$HOOK_PATH" "$@"
        RESULT=$?

    elif [ -f "$HOOK_PATH" ]; then
        sh "$HOOK_PATH" "$@"
        
        RESULT=$?
    fi

    return $RESULT
}

HOOK_NAME=$(basename "$0")
HOOK_FOLDER=$(dirname "$0")

# Execute the old hook if we moved it when installing our hooks.
if [ -x "${HOOK_FOLDER}/${HOOK_NAME}.replaced.githook" ]; then
	ABSOLUTE_FOLDER=$(cd "${HOOK_FOLDER}" && pwd)

    if ! execute_hook "${ABSOLUTE_FOLDER}/${HOOK_NAME}.replaced.githook" "$@"; then
        exit 1
    fi
fi

if [ -d ".githooks/${HOOK_NAME}" ]; then
    # If there is a directory like .githooks/pre-commit,
	#   then for files like .githooks/pre-commit/lint
    for HOOK_FILE in .githooks/"${HOOK_NAME}"/*; do
        if ! execute_hook "$(pwd)/$HOOK_FILE" "$@"; then
            exit 1
        fi
    done

elif [ -f ".githooks/${HOOK_NAME}" ]; then
    if ! execute_hook ".githooks/${HOOK_NAME}" "$@"; then
        exit 1
    fi

fi
'

	HOOK_NAMES="applypatch-msg pre-applypatch post-applypatch "
	HOOK_NAMES="$HOOK_NAMES pre-commit prepare-commit-msg commit-msg post-commit "
	HOOK_NAMES="$HOOK_NAMES pre-rebase post-checkout post-merge pre-push "
	HOOK_NAMES="$HOOK_NAMES pre-receive update post-receive post-update "
	HOOK_NAMES="$HOOK_NAMES push-to-checkout pre-auto-gc post-rewrite sendemail-validate"

	for HOOK in $HOOK_NAMES; do
		HOOK_TEMPLATE="${TARGET_TEMPLATE_DIR}/${HOOK}"

		if [ -x "$HOOK_TEMPLATE" ]; then
            grep 'https://github.com/rycus86/githooks' "${HOOK_TEMPLATE}" > /dev/null 2>&1

			# shellcheck disable=SC2181
			if [ $? -ne 0 ]; then
				echo "Saving existing Git hook: $HOOK"
                mv "$HOOK_TEMPLATE" "$HOOK_TEMPLATE.replaced.githook"
			fi
		fi

        echo "$CONTENT" > "$HOOK_TEMPLATE"
        chmod +x "$HOOK_TEMPLATE"

        echo "Git hook template ready: $HOOK_TEMPLATE"
	done
}

DRY_RUN=$(is_dry_run "$@")
TARGET_TEMPLATE_DIR=""

find_git_hook_templates

if [ "$TARGET_TEMPLATE_DIR" = "" ] || [ ! -d "$TARGET_TEMPLATE_DIR" ]; then
	echo "Git hook templates directory not found"
	exit 1
fi

if [ "$DRY_RUN" = "yes" ]; then
	echo "[Dry run] Would install Git hook templates into $TARGET_TEMPLATE_DIR"
	exit 0
fi

#setup_hook_templates

# TODO ask to find and install the hooks into the existing repos
# TODO maybe change the Git template directory config if that doesn't need root
