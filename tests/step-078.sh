#!/bin/sh
# Test:
#   Cli tool: enable/disable auto updates

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

git config --global --unset githooks.autoupdate.enabled &&
    sh /var/lib/githooks/cli.sh update enable &&
    [ "$(git config --get githooks.autoupdate.enabled)" = "Y" ] ||
    exit 1

git config --global --unset githooks.autoupdate.enabled &&
    sh /var/lib/githooks/cli.sh update disable &&
    [ "$(git config --get githooks.autoupdate.enabled)" = "N" ] ||
    exit 1

# Check the Git alias
git config --global --unset githooks.autoupdate.enabled &&
    git hooks update enable &&
    [ "$(git config --get githooks.autoupdate.enabled)" = "Y" ] ||
    exit 1

git config --global --unset githooks.autoupdate.enabled &&
    git hooks update disable &&
    [ "$(git config --get githooks.autoupdate.enabled)" = "N" ] ||
    exit 1
