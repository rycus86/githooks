#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:centos-base -
FROM centos
RUN yum install -y git curl ca-certificates
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'centos'
