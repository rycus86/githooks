#!/bin/sh

echo "Unset all githooks configs ..."
git config --global --unset githooks.runner
git config --global --unset-all githooks.shared
git config --global --unset githooks.failOnNonExistingSharedHooks
git config --global --unset githooks.maintainOnlyServerHooks
git config --global --unset githooks.autoUpdateEnabled
git config --global --unset githooks.autoUpdateCheckTimestamp
git config --global --unset githooks.cloneUrl
git config --global --unset githooks.cloneBranch
git config --global --unset githooks.previousSearchDir
git config --global --unset githooks.disable
git config --global --unset githooks.installDir
git config --global --unset githooks.deleteDetectedLFSHooks
git config --global --unset githooks.pathForUseCoreHooksPath
git config --global --unset githooks.useCoreHooksPath
git config --global --unset-all githooks.sharedHooksUpdateTriggers
git config --global --unset alias.hooks

git config --global --unset init.templateDir
git config --global --unset core.hooksPath

echo "Remove all test artefacts..."
rm -rf ~/.githooks \
    /usr/share/git-core-my/templates \
    /tmp/test

# Make some test repos
mkdir -p /tmp/test/p001 && mkdir -p /tmp/test/p002 || exit 1
cd /tmp/test/p001 && git init || exit 1
cd /tmp/test/p002 && git init || exit 1

mkdir -p ~/.githooks/templates/hooks &&
    echo "# git-lfs" >~/.githooks/templates/hooks/pre-commit

exit 0
