#!/bin/sh
# Test:
#   Git LFS delegation

# shellcheck disable=SC2016
mkdir -p /tmp/test106-lfs &&
    echo '#!/bin/sh' >/tmp/test106-lfs/git-lfs &&
    echo 'echo "lfs-exec:$1" > /tmp/test106/lfs.out' >/tmp/test106-lfs/git-lfs &&
    chmod +x /tmp/test106-lfs/git-lfs ||
    exit 1

export PATH=/tmp/test106-lfs:"$PATH" || exit 2

sh /var/lib/githooks/install.sh || exit 3

mkdir -p /tmp/test106 &&
    cd /tmp/test106 &&
    git init &&
    git lfs install ||
    exit 4

if ! grep -q 'lfs-exec:install' lfs.out; then
    echo "! Test setup is broken"
    exit 5
fi

mkdir -p /tmp/test106/.githooks &&
    echo '#!/bin/sh' >/tmp/test106/.githooks/post-commit &&
    echo 'echo "Regular hook run" > /tmp/test106/hook.out' >/tmp/test106/.githooks/post-commit ||
    exit 6

git add .githooks &&
    ACCEPT_CHANGES=Y git commit -m 'Test commit' ||
    exit 7

if ! grep -q 'Regular hook run' hook.out; then
    echo "! Regular hook did not run"
    exit 8
fi

if ! grep -q 'post-commit' lfs.out; then
    echo "! LFS hook did not run"
    exit 9
fi

# Test LFS invocation if git hooks are disabled
rm lfs.out && rm hook.out &&
    git hooks config set disable &&
    ACCEPT_CHANGES=Y git commit --allow-empty -m "Second commit" ||
    exit 10

if ! grep -q 'post-commit' lfs.out || [ -f hook.out ]; then
    echo "! LFS hook did not run or the normal hook ran"
    exit 11
fi

# an extra invocation for coverage
HOOK_NAME=post-merge HOOK_FOLDER=$(pwd)/.git/hooks \
    sh ~/.githooks/release/base-template-wrapper.sh unused ||
    exit 12

if ! grep -q 'post-merge' lfs.out; then
    echo "! LFS hook did not run"
    exit 13
fi
