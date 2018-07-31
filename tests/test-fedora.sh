#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:fedora-base -
FROM fedora
RUN yum install -y git
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'fedora'
