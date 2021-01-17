#!/bin/sh
# Test:
#   Trigger hooks on a bare repo with a push from a local repo.

git config --global githooks.testingTreatFileProtocolAsRemote "true"

if ! "$GH_TEST_BIN/installer"; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p "$GH_TEST_TMP/test110/hooks" &&
    mkdir -p "$GH_TEST_TMP/test110/server" &&
    mkdir -p "$GH_TEST_TMP/test110/local" || exit 1

# Hooks
cd "$GH_TEST_TMP/test110/hooks" && git init || exit 1
"$GITHOOKS_INSTALL_BIN_DIR/cli" config disable --set || exit 1

# Server
cd "$GH_TEST_TMP/test110/server" && git init --bare || exit 1
# Repo
git clone "$GH_TEST_TMP/test110/server" "$GH_TEST_TMP/test110/local" || exit 1

echo "Setup hooks"
cd "$GH_TEST_TMP/test110/hooks" || exit 1
mkdir -p ".githooks/update"
HOOK=".githooks/update/testhook"
echo "#!/bin/sh" >"$HOOK"
echo "echo 'Update hook run'" >>"$HOOK"
echo "exit 1" >>"$HOOK"
chmod u+x "$HOOK"
git add "$HOOK" || exit 1
git commit -a -m "Hooks" || exit 1

echo "Setup shared hook in server repo"
cd "$GH_TEST_TMP/test110/server" || exit 1
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared add file://"$GH_TEST_TMP/test110/hooks" || exit 1
echo "Setup shared hook in server repo: set trusted"
"$GITHOOKS_INSTALL_BIN_DIR/cli" config trusted --accept || exit 1
echo "Setup shared hook in server repo: update shared"
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared update || exit 1

echo "Test hook from push"
cd "$GH_TEST_TMP/test110/local" || exit 1
echo "Test" >Test
git add Test || exit 1
git commit -a -m "First" || exit 1
echo "Push hook to fail"
OUTPUT=$(git push 2>&1)

# shellcheck disable=SC2181
if [ $? -eq 0 ] || ! echo "$OUTPUT" | grep -q "Update hook run"; then
    echo "!! Push should have failed and update hook should have run. Output:"
    echo "$OUTPUT"
    exit 1
fi

echo "Modify hook to succeed"
cd "$GH_TEST_TMP/test110/hooks" || exit 1
sed -i 's/exit 1/exit 0/g' "$HOOK"
git commit -a -m "Make hook succeed"

echo "Update hooks"
cd "$GH_TEST_TMP/test110/server" || exit 1
"$GITHOOKS_INSTALL_BIN_DIR/cli" shared update || exit 1

echo "Push hook to succeed"
cd "$GH_TEST_TMP/test110/local" || exit 1
OUTPUT=$(git push 2>&1)

# shellcheck disable=SC2181
if [ $? -ne 0 ] || ! echo "$OUTPUT" | grep -q "Update hook run"; then
    echo "!! Push should have succeeded and update hook should have run. Output:"
    echo "$OUTPUT"
    exit 1
fi

exit 0
