#!/bin/sh
# Test:
#   Cli tool: enable/disable auto updates

if ! /var/lib/githooks/githooks/bin/installer --stdin; then
    echo "! Failed to execute the install script"
    exit 1
fi

git config --global --unset githooks.autoupdate.enabled &&
    git hooks update enable &&
    [ "$(git config --get githooks.autoupdate.enabled)" = "true" ] ||
    exit 1

git config --global --unset githooks.autoupdate.enabled &&
    git hooks update disable &&
    [ "$(git config --get githooks.autoupdate.enabled)" = "false" ] ||
    exit 1

# Check the Git alias
git config --global --unset githooks.autoupdate.enabled &&
    git hooks update enable &&
    [ "$(git config --get githooks.autoupdate.enabled)" = "true" ] ||
    exit 1

git config --global --unset githooks.autoupdate.enabled &&
    git hooks update disable &&
    [ "$(git config --get githooks.autoupdate.enabled)" = "false" ] ||
    exit 1
