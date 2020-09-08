#!/bin/sh
# Test:
#   Cli tool: manage local shared hook repositories

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/shared/first-shared.git/.githooks/pre-commit &&
    mkdir -p /tmp/shared/second-shared.git/.githooks/pre-commit &&
    mkdir -p /tmp/shared/third-shared.git/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/shared/first-shared.git/.githooks/pre-commit/sample-one &&
    echo 'echo "Hello"' >/tmp/shared/second-shared.git/.githooks/pre-commit/sample-two &&
    echo 'echo "Hello"' >/tmp/shared/third-shared.git/.githooks/pre-commit/sample-three &&
    (cd /tmp/shared/first-shared.git && git init && git add . && git commit -m 'Testing') &&
    (cd /tmp/shared/second-shared.git && git init && git add . && git commit -m 'Testing') &&
    (cd /tmp/shared/third-shared.git && git init && git add . && git commit -m 'Testing') ||
    exit 1

mkdir -p /tmp/test083 && cd /tmp/test083 && git init || exit 1

git hooks shared add --local /tmp/shared/first-shared.git &&
    git hooks shared list | grep "first_shared" | grep "pending" &&
    git hooks shared pull &&
    git hooks shared list | grep "first_shared" | grep "active" &&
    git hooks shared add --local /tmp/shared/second-shared.git &&
    git hooks shared add /tmp/shared/third-shared.git &&
    git hooks shared list --local | grep "second_shared" | grep "pending" &&
    git hooks shared list --all | grep "third_shared" | grep "pending" &&
    (cd ~/.githooks/shared/shared_first_shared &&
        git remote rm origin &&
        git remote add origin /some/other/url.git) &&
    git hooks shared list | grep "first_shared" | grep "invalid" &&
    git hooks shared remove --local /tmp/shared/first-shared.git &&
    ! git hooks shared list | grep "first_shared" &&
    git hooks shared remove --local /tmp/shared/second-shared.git &&
    git hooks shared remove /tmp/shared/third-shared.git &&
    [ ! -f "$(pwd)/.githooks/.shared" ] ||
    exit 2

git hooks shared clear --all &&
    git hooks shared purge ||
    exit 8

# Check the Git alias
git hooks shared add --local /tmp/shared/first-shared.git &&
    git hooks shared list | grep "first_shared" | grep "pending" &&
    git hooks shared pull &&
    git hooks shared list | grep "first_shared" | grep "active" &&
    git hooks shared add --local /tmp/shared/second-shared.git &&
    git hooks shared add /tmp/shared/third-shared.git &&
    git hooks shared list --local | grep "second_shared" | grep "pending" &&
    git hooks shared list --all | grep "third_shared" | grep "pending" &&
    (cd ~/.githooks/shared/shared_first_shared &&
        git remote rm origin &&
        git remote add origin /some/other/url.git) &&
    git hooks shared list --with-url | grep "first_shared" | grep "invalid" &&
    git hooks shared remove --local /tmp/shared/first-shared.git &&
    ! git hooks shared list | grep "first_shared" &&
    git hooks shared remove --local /tmp/shared/second-shared.git &&
    git hooks shared remove /tmp/shared/third-shared.git &&
    [ ! -f "$(pwd)/.githooks/.shared" ] ||
    exit 9
