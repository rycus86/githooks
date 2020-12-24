#!/bin/sh
# Test:
#   Direct template execution: test a single pre-commit hook file with a runner script

# Pseudo installation.
mkdir -p ~/.githooks/release &&
    cp -r /var/lib/githooks/githooks/bin ~/.githooks ||
    exit 1
mkdir -p /tmp/test12 && cd /tmp/test12 || exit 2
git init || exit 3

launch=".githooks/lau nch" # whitespace is intentional
# shellcheck disable=SC2016
mkdir -p .githooks &&
    echo '"Hello"' >.githooks/pre-commit &&
    echo '#/bin/bash' >"$launch" &&
    echo 'echo "Launch:"' >>"$launch" &&
    echo 'echo "Args:$1,$2,$3,$4,$5,$6"' >>"$launch" &&
    echo 'cat "$7"' >>"$launch" &&
    chmod u+x "$launch" &&
    echo "/bin/bash '$launch' '\${MONKEY}' \"\$MONKEY\" \${MONKEY} \$\$MONKEY \$\${MONKEY}" >.githooks/pre-commit.runner ||
    exit 4

# Execute pre-commit by the runner
OUT=$(MONKEY="mon key" ~/.githooks/bin/runner "$(pwd)"/.git/hooks/pre-commit 2>&1)

# shellcheck disable=SC2181,SC2016
if [ "$?" -ne 0 ] || ! echo "$OUT" | grep "Hello" ||
    ! echo "$OUT" | grep 'Args:mon key,mon key,mon,key,$MONKEY,${MONKEY}'; then
    echo "! Expected hook with runner command to be executed. $OUT"
    exit 5
fi
