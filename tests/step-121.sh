#!/bin/sh
# Test:
#   Issue #153: Bugfix: Test shared hook repo splitting

mkdir ~/test121 && cd ~/test121 && git init

# shellcheck disable=SC1091
. /var/lib/githooks/base-template.sh

check_url_split() {
    TARGET="$1"
    EXPECTED_URL="$2"
    EXPECTED_BRANCH="$3"

    set_shared_root "$TARGET"

    if [ "$SHARED_REPO_CLONE_URL" != "$EXPECTED_URL" ] || [ "$SHARED_REPO_CLONE_BRANCH" != "$EXPECTED_BRANCH" ]; then
        echo "URL or branch not matched:"
        echo "     URL expected=$EXPECTED_URL"
        echo "              was=$SHARED_REPO_CLONE_URL"
        echo "  Branch expected=$EXPECTED_BRANCH"
        echo "              was=$SHARED_REPO_CLONE_BRANCH"
        echo "! Failed to split $TARGET"
        exit 1
    fi
}

check_url_split "file:///tmp/shared/shared-server.git@testbranch2" "file:///tmp/shared/shared-server.git" "testbranch2"
check_url_split "git@github.com:shared/hooks-maven.git" "git@github.com:shared/hooks-maven.git" ""
check_url_split "git@github.com:shared/hooks-maven.git@example" "git@github.com:shared/hooks-maven.git" "example"
check_url_split "ssh://git@github.com/shared/hooks-maven.git" "ssh://git@github.com/shared/hooks-maven.git" ""
check_url_split "ssh://git@github.com/shared/hooks-maven.git@tests" "ssh://git@github.com/shared/hooks-maven.git" "tests"
check_url_split "ssh://user@github.com/shared/special-hooks.git@v3.3.3" "ssh://user@github.com/shared/special-hooks.git" "v3.3.3"
check_url_split "ssh://user@github.com/shared/special-hooks.git@otherbranch" "ssh://user@github.com/shared/special-hooks.git" "otherbranch"
