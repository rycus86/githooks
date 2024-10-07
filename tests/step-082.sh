#!/bin/sh
# Test:
#   Cli tool: manage global shared hook repositories

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

git config --global githooks.trust.all N

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

mkdir -p /tmp/test082 && cd /tmp/test082 && git init || exit 1

testShared() {
    git hooks shared add --global file:///tmp/shared/first-shared.git &&
        git hooks shared list | grep "first-shared" | grep "pending" &&
        git hooks shared pull &&
        git hooks shared list | grep "first-shared" | grep "active" &&
        git hooks shared add --global file:///tmp/shared/second-shared.git &&
        git hooks shared add --global file:///tmp/shared/third-shared.git &&
        git hooks shared list --global | grep "second-shared" | grep "pending" &&
        git hooks shared list --all | grep "third-shared" | grep "pending" &&
        (cd ~/.githooks/shared/*tmp-shared-first-shared-git* &&
            git remote rm origin &&
            git remote add origin /some/other/url.git) &&
        git hooks shared list | grep "first-shared" | grep "invalid" &&
        git hooks shared remove --global file:///tmp/shared/first-shared.git &&
        ! git hooks shared list | grep "first-shared" &&
        git hooks shared remove --global file:///tmp/shared/second-shared.git &&
        git hooks shared remove --global file:///tmp/shared/third-shared.git &&
        [ -z "$(git config --global --get-all githooks.shared)" ] ||
        return 1
}

testShared || exit 1

git hooks shared clear --all &&
    git hooks shared purge ||
    exit 8

# Check the Git alias
testShared || exit 9
