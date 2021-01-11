#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:opensuse-base -
FROM opensuse/tumbleweed
RUN zypper install -y git-core
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'opensuse' "$@"
