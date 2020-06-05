#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:alpine-lfs-base -
FROM alpine
RUN apk add --no-cache git git-lfs
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'alpine-lfs' "$@"
