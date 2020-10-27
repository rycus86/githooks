#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:alpine-lfs-go-base -
FROM golang:1.15.3-alpine
RUN apk add --no-cache git git-lfs bash
EOF

exec sh "$TEST_DIR"/exec-tests-go.sh 'alpine-lfs-go' "$@"
