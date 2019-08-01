#!/bin/sh
# Test:
#   Git LFS: fail when required but not found

# make sure we don't have LFS installed
if git-lfs --version; then
    echo "git-lfs is available but we need it missing"
    exit 249
fi

# run Githooks install
sh /var/lib/githooks/install.sh || exit 1

# setup the first repository
mkdir -p /tmp/test107a/.githooks &&
    cd /tmp/test107a &&
    touch .githooks/.lfs-required &&
    touch .githooks/keep-dir &&
    git init &&
    git add .githooks ||
    exit 2

# this will only fail in `post-commit` where the exit code is ignored
git commit -m "Test commit" || exit 3

# try to clone, which should fail on `post-checkout`
if git clone /tmp/test107a /tmp/test107b; then
    echo "! Clone was expected to fail on post-checkout"
    exit 4
fi

# drop the LFS required file from the first repo
cd /tmp/test107a &&
    rm -f .githooks/.lfs-required &&
    git add --all .githooks/.lfs-required &&
    git commit -m "Remove LFS required for now" ||
    exit 5

# try the `clone` again which should now work
git clone /tmp/test107a /tmp/test107c &&
    cd /tmp/test107c &&
    git checkout -b testing &&
    # add the LFS requirement back
    touch testing &&
    touch .githooks/.lfs-required &&
    git add testing .githooks/.lfs-required &&
    # only `post-commit` fails here
    git commit -m "Additional commit" ||
    exit 6

# this should fail on `pre-push`
if git push -u origin testing; then
    echo "! Push was expected to fail on pre-push"
    exit 7
fi
