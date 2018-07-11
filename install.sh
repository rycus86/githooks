#!/bin/sh

TARGET_TEMPLATE_DIR=""

find_git_templates() {
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

	echo -n 'Could not find the Git templates directory, do you want to search for it? [yN] '
	read -r DO_SEARCH

	if [ "${DO_SEARCH}" = "y" ] || [ "${DO_SEARCH}" = "Y" ]; then
		echo "Searching for potential locations..."
		for HIT in $(find / 2>/dev/null | grep "templates/hooks/pre-commit.sample"); do
			HIT=$(dirname "$HIT")

			echo -n "- Is it $HIT ? [yN] "
			read -r ACCEPT

			if [ "$ACCEPT" = "y" ] || [ "$ACCEPT" = "Y" ]; then
				TARGET_TEMPLATE_DIR="$HIT"
				return
			fi
		done
	fi
}

setup_hook_templates() {
	CONTENT='#!/bin/sh
# Base githooks template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.

HOOK_NAME=$(basename "$0")
HOOK_FOLDER=$(dirname "$0")

# Execute the old hook if we moved it when installing our hooks.
if [ -x "${HOOK_FOLDER}/${HOOK_NAME}.replaced.githook" ]; then
    eval "${HOOK_FOLDER}/${HOOK_NAME}.replaced.githook"
fi

if [ -d ".githooks/${HOOK_NAME}" ]; then
    # If there is a directory like .githooks/pre-commit,
	# then for files like .githooks/pre-commit/lint
    for HOOK_FILE in .githooks/${HOOK_NAME}/*; do
        # Either execute directly or as a Shell script
        if [ -x "$HOOK_FILE" ]; then
            eval "$HOOK_FILE"
        elif [ -f "$HOOK_FILE" ]; then
            sh "$HOOK_FILE"
        fi
    done
elif [ -x ".githooks/${HOOK_NAME}" ]; then
    # Execute the file directly
    eval ".githooks/${HOOK_NAME}"
elif [ -f ".githooks/${HOOK_NAME}" ]; then
    # Execute as a Shell script
    sh ".githooks/${HOOK_NAME}"
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

			if [ $? -ne 0 ]; then
				echo "Saving existing hook: $HOOK"
                mv "$HOOK_TEMPLATE" "$HOOK_TEMPLATE.replaced.githook"
			fi
		fi

        echo "$CONTENT" > "$HOOK_TEMPLATE"
        chmod +x "$HOOK_TEMPLATE"

        echo "Hook template ready: $HOOK_TEMPLATE"
	done
}

find_git_templates

if [ "$TARGET_TEMPLATE_DIR" = "" ] || [ ! -d "$TARGET_TEMPLATE_DIR" ]; then
	echo "Git templates directory not found"
	exit 1
fi

setup_hook_templates

# TODO ask to find and install the hooks into the existing repos
# TODO maybe change the Git template directory config if that doesn't need root
