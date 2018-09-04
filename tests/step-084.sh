#!/bin/sh
# Test:
#   Cli tool: shared hook repository management failures

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

sh /var/lib/githooks/cli.sh shared unknown && exit 2
rm -rf ~/.githooks/shared &&
    sh /var/lib/githooks/cli.sh shared purge && exit 3
sh /var/lib/githooks/cli.sh shared add && exit 4
sh /var/lib/githooks/cli.sh shared remove && exit 5
sh /var/lib/githooks/cli.sh shared add --local /tmp/some/repo.git && exit 6
sh /var/lib/githooks/cli.sh shared remove --local /tmp/some/repo.git && exit 7
sh /var/lib/githooks/cli.sh shared clear && exit 8
sh /var/lib/githooks/cli.sh shared clear unknown && exit 9
sh /var/lib/githooks/cli.sh shared list unknown && exit 10
if sh /var/lib/githooks/cli.sh shared list --local; then
    exit 11
fi

# Check the Git alias
git hooks shared unknown && exit 12
rm -rf ~/.githooks/shared &&
    git hooks shared purge && exit 13
git hooks shared add && exit 14
git hooks shared remove && exit 15
git hooks shared add --local /tmp/some/repo.git && exit 16
git hooks shared remove --local /tmp/some/repo.git && exit 17
git hooks shared clear && exit 18
git hooks shared clear unknown && exit 19
git hooks shared list unknown && exit 20
if git hooks shared list --local; then
    exit 21
fi
