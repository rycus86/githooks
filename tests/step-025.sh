#!/bin/sh
# Test:
#   Direct template execution: break if the previously moved hook is failing

mkdir -p "$GH_TEST_TMP/test25" && cd "$GH_TEST_TMP/test25" || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo "echo 'Direct execution' >> '$GH_TEST_TMP/test025.out'" >>.githooks/pre-commit/test &&
    echo "#!/bin/sh" >.git/hooks/pre-commit.replaced.githook &&
    echo 'exit 1' >>.git/hooks/pre-commit.replaced.githook &&
    chmod +x .git/hooks/pre-commit.replaced.githook &&
    "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

printf 'patterns:\n   - "**/*.replaced.githook"' >.git/.githooks.ignore.yaml &&
    "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit ||
    exit 1
