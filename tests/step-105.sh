#!/bin/sh
# Test:
#   Git LFS integration

if ! git-lfs --version; then
    echo "git-lfs is not available"
    exit 249
fi

mkdir -p /tmp/test105 &&
    cd /tmp/test105 &&
    git init &&
    git lfs install ||
    exit 1

IFS="
"

LFS_UNMANAGED=""

# shellcheck disable=SC2013
for LFS_HOOK_PATH in $(grep -l git-lfs .git/hooks/*); do
    LFS_HOOK=$(basename "$LFS_HOOK_PATH")

    if ! grep '&& CAN_RUN_LFS_HOOK="true"' /var/lib/githooks/base-template.sh | grep -q "$LFS_HOOK"; then
        echo "! LFS hook appears unmanaged: $LFS_HOOK"
        LFS_UNMANAGED=Y
    fi
done

unset IFS

[ -z "$LFS_UNMANAGED" ] || exit 2
