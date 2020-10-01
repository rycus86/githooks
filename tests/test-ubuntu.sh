#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:ubuntu-base -
FROM ubuntu
RUN apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        git-core apt-transport-https ca-certificates && \
    update-ca-certificates
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'ubuntu' "$@"
