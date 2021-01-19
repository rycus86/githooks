#!/bin/sh
git config --global user.email "githook@test.com" &&
    git config --global user.name "Githook Tests" &&
    git config --global init.defaultBranch master &&
    git config --global core.autocrlf false || exit 1

rm -rf "$GH_TEST_REPO/.git" || exit 1
# We use the bin folder.
sed -i -E 's/^bin//' "$GH_TEST_REPO/githooks/.gitignore" || exit 1

echo "Make test gitrepo to clone from ..." &&
    cd "$GH_TEST_REPO" && git init >/dev/null 2>&1 &&
    git add . >/dev/null 2>&1 &&
    git commit -a -m "Before build" >/dev/null 2>&1 || exit 1

# Build binaries for v9.9.0.
#################################
cd "$GH_TEST_REPO/githooks" &&
    git tag "v9.9.0" &&
    ./scripts/clean.sh &&
    ./scripts/build.sh --build-flags "-tags debug,mock" &&
    ./bin/installer --version || exit 1
echo "Commit build v9.9.0 to repo ..." &&
    cd "$GH_TEST_REPO" &&
    git add . >/dev/null 2>&1 &&
    git commit -a --allow-empty -m "Version 9.9.0" >/dev/null 2>&1 &&
    git tag -f "v9.9.0" || exit 1

# Build binaries for v9.9.1.
#################################
cd "$GH_TEST_REPO/githooks" &&
    git commit -a --allow-empty -m "Before build" >/dev/null 2>&1 &&
    git tag -f "v9.9.1" &&
    ./scripts/clean.sh &&
    ./scripts/build.sh --build-flags "-tags debug,mock" &&
    ./bin/installer --version || exit 1
echo "Commit build v9.9.1 to repo ..." &&
    cd "$GH_TEST_REPO" &&
    git commit -a --allow-empty -m "Version 9.9.1" >/dev/null 2>&1 &&
    git tag -f "v9.9.1" || exit 1

if [ -n "$EXTRA_INSTALL_ARGS" ]; then
    sed -i -E "s|(.*)/installer\"|\1/installer\" $EXTRA_INSTALL_ARGS|g" "$GH_TESTS"/step-*
fi
