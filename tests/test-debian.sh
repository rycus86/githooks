#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:debian-base -
FROM debian
RUN apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        git-core curl ca-certificates
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'debian'
