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
# Sets ${TARGET_TEMPLATE_DIR} if found.
#
# Returns:
#   None
############################################################
find_git_hook_templates() {
	# 1. from environment variables
	mark_directory_as_target "$GIT_TEMPLATE_DIR"
	if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi

	# 2. from git config
	mark_directory_as_target "$(git config --get init.templateDir)"
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
		if [ "$TARGET_TEMPLATE_DIR" != "" ]; then return; fi
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
	if [ "$1" = "" ]; then
		return
	fi

	if [ -w "$1" ]; then
		TARGET_TEMPLATE_DIR="$1"
		return
	fi

	# Try to see if the path is given with a tilde
	TILDE_REPLACED=$(echo "$1" | awk 'gsub("~", "'"$HOME"'", $0)')
	if [ -w "$TILDE_REPLACED" ]; then
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
			grep 'https://github.com/rycus86/githooks' "${HOOK_TEMPLATE}" >/dev/null 2>&1

			# shellcheck disable=SC2181
			if [ $? -ne 0 ]; then
				echo "Saving existing Git hook: $HOOK"
				mv "$HOOK_TEMPLATE" "$HOOK_TEMPLATE.replaced.githook"
			fi
		fi

		echo "$CONTENT" >"$HOOK_TEMPLATE"
		chmod +x "$HOOK_TEMPLATE"

		echo "Git hook template ready: $HOOK_TEMPLATE"
	done
}

############################################################
# Main program flow below:
#   - check if we're running in dry-run mode
#   - find the Git hook template directory to install into
#   - setup the new hooks in the template directory
############################################################

DRY_RUN=$(is_dry_run "$@")
TARGET_TEMPLATE_DIR=""

find_git_hook_templates

if [ ! -d "$TARGET_TEMPLATE_DIR" ]; then
	echo "Git hook templates directory not found"
	exit 1
fi

if [ "$DRY_RUN" = "yes" ]; then
	echo "[Dry run] Would install Git hook templates into $TARGET_TEMPLATE_DIR"
	exit 0
fi

setup_hook_templates

# TODO ask to find and install the hooks into the existing repos
# TODO maybe change the Git template directory config if that doesn't need root
