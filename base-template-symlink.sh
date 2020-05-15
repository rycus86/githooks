#!/bin/sh
# Base Git hook template from https://github.com/rycus86/githooks
#
# It allows you to have a .githooks folder per-project that contains
# its hooks to execute on various Git triggers.
#
# Version: 2005.151157-80e089

INSTALL_DIR=$(git config --global githooks.installDir)
GITHOOKS_SCRIPT="$INSTALL_DIR/release/base-template.sh"

if [ ! -d "$INSTALL_DIR" ]; then
    echo "! Githooks installation is corrupt! " >&2
    echo "  Install directory at '${INSTALL_DIR}' is missing." >&2
    echo "  Please run the Githooks install script again to fix it." >&2
    exit 1
elif [ ! -f "$GITHOOKS_SCRIPT" ]; then
    echo "! Githooks link to '$GITHOOKS_SCRIPT' is broken!"
    echo "  Please run the Githooks install script again to fix it." >&2
    exit 1
fi

# shellcheck disable=SC1090
. "$GITHOOKS_SCRIPT"
