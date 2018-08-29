#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:alpine-curl-base -
FROM alpine
RUN apk add --no-cache git curl ca-certificates
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'alpine-curl'
