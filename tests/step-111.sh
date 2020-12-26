#!/bin/sh
# Test:
#   Run an install that deletes/backups existing detected LFS hooks in existing repos

if echo "$EXTRA_INSTALL_ARGS" | grep -q "use-core-hookspath"; then
    echo "Using core.hooksPath"
    exit 249
fi

mkdir -p /tmp/test109.1/.githooks/pre-commit &&
    cd /tmp/test109.1 &&
    echo 'echo "In-repo" >> /tmp/test-109.out' >.githooks/pre-commit/test &&
    git init && mkdir -p .git/hooks &&
    echo 'echo "Previous1" >> /tmp/test-109.out ; # git lfs arg1 arg2' >.git/hooks/pre-commit &&
    chmod +x .git/hooks/pre-commit ||
    exit 1

mkdir -p /tmp/test109.2/.githooks/pre-commit &&
    cd /tmp/test109.2 && git init && mkdir -p .git/hooks &&
    echo 'echo "Previous2" >> /tmp/test-109.out ; # git-lfs arg1 arg2' >.git/hooks/pre-commit &&
    chmod +x .git/hooks/pre-commit ||
    exit 1

mkdir -p /tmp/test109.3/.githooks/pre-commit &&
    cd /tmp/test109.3 && git init && mkdir -p .git/hooks &&
    echo 'echo "Previous3" >> /tmp/test-109.out ; # git  lfs arg1 arg2' >.git/hooks/pre-commit &&
    chmod +x .git/hooks/pre-commit ||
    exit 1

git config --global --unset githooks.deleteDetectedLFSHooks

echo 'n
y
/tmp
y

n
' | /var/lib/githooks/githooks/bin/installer --stdin || exit 1

if [ -f "/tmp/test109.1/.git/hooks/pre-commit.disabled.githooks" ]; then
    echo '! Expected hook to be deleted'
    exit 1
fi
if [ ! -f "/tmp/test109.2/.git/hooks/pre-commit.disabled.githooks" ] &&
    [ ! -f "/tmp/test109.3/.git/hooks/pre-commit.disabled.githooks" ]; then
    echo '! Expected hook to be moved'
    exit 1
fi

cd /tmp/test109.2 &&
    git commit --allow-empty -m 'Init' 2>/dev/null || exit 1
if grep 'Previous2' /tmp/test-109.out; then
    echo '! Expected hook to be disabled'
    exit 1
fi

cd /tmp/test109.3 &&
    git commit --allow-empty -m 'Init' 2>/dev/null || exit 1
if grep 'Previous3' /tmp/test-109.out; then
    echo '! Expected hook to be disabled'
    exit 1
fi

out=$(git hooks config print delete-detected-lfs-hooks)
if ! echo "$out" | grep -q "default disabled and backed up"; then
    echo "! Expected the correct config behavior"
    echo "$out"
fi

# For coverage
git hooks config reset delete-detected-lfs-hooks || exit 1
out=$(git hooks config print delete-detected-lfs-hooks)
if ! echo "$out" | grep -q "default disabled and backed up"; then
    echo "! Expected the correct config behavior"
    echo "$out"
fi

# Reset every repo and do again
# Repo 1 no delete
# Repo 2,3 always delete
cd /tmp/test109.2/.git/hooks && mv -f pre-commit.disabled.githooks pre-commit || exit 1
cd /tmp/test109.3/.git/hooks && mv -f pre-commit.disabled.githooks pre-commit || exit 1
cd /tmp/test109.1 && echo 'echo "Previous1" >> /tmp/test-109.out ; # git lfs arg1 arg2' >.git/hooks/pre-commit || exit 1

echo 'n
y
/tmp
N
a
' | /var/lib/githooks/githooks/bin/installer --stdin || exit 1

if [ ! -f "/tmp/test109.1/.git/hooks/pre-commit.disabled.githooks" ]; then
    echo '! Expected hook to be moved'
    exit 1
fi
if [ -f "/tmp/test109.2/.git/hooks/pre-commit.disabled.githooks" ] &&
    [ -f "/tmp/test109.3/.git/hooks/pre-commit.disabled.githooks" ]; then
    echo '! Expected hook to be deleted'
    exit 1
fi
