#!/bin/sh
# Test:
#   Git LFS delegation

onExit() {
    if [ -n "$ORIGINAL_GIT_LFS" ]; then
        cp -f "$GH_TEST_TMP/test106-lfs/git-lfs-backup" "$ORIGINAL_GIT_LFS" || {
            echo "WARNING: LFS recovery failure! All succeeding tests will be UNSTABLE!"
            exit 111
        }
    fi
}

# Make our own executable git-lfs
# On Windows we need it anyways because mocking it is
# impossible with a shell script.
mkdir -p "$GH_TEST_TMP/test106-lfs" &&
    mkdir -p "$GH_TEST_TMP/test106" || exit 1

cat <<"EOF" >"$GH_TEST_TMP/test106-lfs/git-lfs.go" || exit 2
package main

import (
    "fmt"
    "os"
)

func main() {
    f, err := os.Create(os.Getenv("GH_TEST_TMP") + "/test106/lfs.out")
    if err != nil {
        fmt.Printf("git-lfs-mock failed!")
        panic(err)
    }
    defer f.Close()
    fmt.Fprintf(f, "lfs-exec:%s", os.Args[1])
}
EOF

# Compile and test it.
# shellcheck disable=SC2211
cd "$GH_TEST_TMP/test106-lfs" &&
    go build -o git-lfs ./... &&
    ./git-lfs testing &&
    [ -f "$GH_TEST_TMP/test106/lfs.out" ] &&
    rm -f "$GH_TEST_TMP/test106/lfs.out" || exit 3

if uname | grep -q "MINGW"; then
    # On windows replace the original git-lfs completely,
    # because git.exe perturbates the PATH
    ORIGINAL_GIT_LFS=$(cygpath -m "$(command -v git-lfs)")
    cp -f "$ORIGINAL_GIT_LFS" "$GH_TEST_TMP/test106-lfs/git-lfs-backup" &&
        cp -f "$GH_TEST_TMP/test106-lfs/git-lfs" "$ORIGINAL_GIT_LFS" || exit 4
    trap onExit EXIT # Move the original back in place
else
    # On Unix, a git-lfs shell script is enough.
    export PATH="$GH_TEST_TMP/test106-lfs:$PATH" || exit 4
fi

"$GH_TEST_BIN/installer" || exit 5

cd "$GH_TEST_TMP/test106" &&
    git init &&
    git lfs install ||
    exit 6

if ! grep -q 'lfs-exec:install' lfs.out; then
    echo "! Test setup is broken"
    exit 7
fi

mkdir -p "$GH_TEST_TMP/test106/.githooks" &&
    echo '#!/bin/sh' >"$GH_TEST_TMP/test106/.githooks/post-commit" &&
    echo "echo 'Regular hook run' > '$GH_TEST_TMP/test106/hook.out'" >"$GH_TEST_TMP/test106/.githooks/post-commit" ||
    exit 8

git add .githooks &&
    ACCEPT_CHANGES=Y git commit -m 'Test commit' ||
    exit 9

if ! grep -q 'Regular hook run' hook.out; then
    echo "! Regular hook did not run"
    exit 10
fi

if ! grep -q 'post-commit' lfs.out; then
    echo "! LFS hook did not run"
    exit 11
fi

# Test LFS invocation if git hooks are disabled
rm lfs.out && rm hook.out &&
    "$GITHOOKS_INSTALL_BIN_DIR/cli" config disable --set &&
    ACCEPT_CHANGES=Y git commit --allow-empty -m "Second commit" ||
    exit 12

if ! grep -q 'post-commit' lfs.out || [ -f hook.out ]; then
    echo "! LFS hook did not run or the normal hook ran"
    exit 13
fi

# an extra invocation for coverage
"$GITHOOKS_INSTALL_BIN_DIR/runner" "$(pwd)"/.git/hooks/post-merge unused ||
    exit 12

if ! grep -q 'post-merge' lfs.out; then
    echo "! LFS hook did not run"
    exit 14
fi
