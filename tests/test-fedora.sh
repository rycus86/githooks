#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:fedora-base -
FROM fedora
RUN dnf install -y git awk findutils
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'fedora' "$@"
