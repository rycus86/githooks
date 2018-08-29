#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:alpine-wget-base -
FROM alpine
RUN apk add --no-cache git wget ca-certificates
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'alpine-wget'
