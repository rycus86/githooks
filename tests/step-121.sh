#!/bin/sh
# Test:
#   Direct template execution: test a single pre-commit hook file with a runner script

mkdir -p "$GH_TEST_TMP/test121" &&
    cd "$GH_TEST_TMP/test121" || exit 2
git init || exit 3

# Make our own runner.
cat <<"EOF" >"custom-runner.go" || exit 3
package main

import (
    "fmt"
    "os"
    "strings"
)

func main() {
    fmt.Printf("Hello\n")
    fmt.Printf("File:%s\n", os.Args[1])
    fmt.Printf("Args:%s\n", strings.Join(os.Args[2:], ","))
}
EOF

go build -o custom-runner.exe ./... || exit 4

# shellcheck disable=SC2016
mkdir -p .githooks &&
    echo 'Hello' >.githooks/pre-commit &&
    echo "'$GH_TEST_TMP/test121/custom-runner.exe' 'my-file.py' '\${MONKEY}' \"\$MONKEY\" \${MONKEY} \$\$MONKEY \$\${MONKEY}" >.githooks/pre-commit.runner ||
    exit 5

# Execute pre-commit by the runner
OUT=$(MONKEY="mon key" "$GH_TEST_BIN/runner" "$(pwd)"/.git/hooks/pre-commit 2>&1)

# shellcheck disable=SC2181,SC2016
if [ "$?" -ne 0 ] ||
    ! echo "$OUT" | grep "Hello" ||
    ! echo "$OUT" | grep "my-file.py" ||
    ! echo "$OUT" | grep 'Args:mon key,mon key,mon,key,$MONKEY,${MONKEY}'; then
    echo "! Expected hook with runner command to be executed."
    echo "$OUT"
    exit 6
fi
