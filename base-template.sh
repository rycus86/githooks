#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.

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
		(cat ".githooks/.ignore" ; echo) > "$ALL_IGNORE_FILE"
	fi
	if [ -f ".githooks/${HOOK_NAME}/.ignore" ]; then
		(cat ".githooks/${HOOK_NAME}/.ignore" ; echo) >> "$ALL_IGNORE_FILE"
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
	done < "$ALL_IGNORE_FILE"

	# Remove the temporary file
	rm -f "$ALL_IGNORE_FILE"

	# If this file is ignored, stop
	if [ -n "$IS_IGNORED" ]; then
		return 0
	fi

	# Assume success by default
	RESULT=0

	if [ -x "$HOOK_PATH" ]; then
		# Run as an executable file
		"$HOOK_PATH" "$@"
		RESULT=$?

	elif [ -f "$HOOK_PATH" ]; then
		# Run as a Shell script
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

# Execute all hooks in a directory, or a file named as the hook
if [ -d ".githooks/${HOOK_NAME}" ]; then
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
