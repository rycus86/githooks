#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:alpine-lfs-go-corehookspath-base -
FROM golang:1.15.6-alpine
RUN apk add git git-lfs --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/main --allow-untrusted
RUN apk add bash
ENV EXTRA_INSTALL_ARGS --use-core-hookspath
EOF

exec sh "$TEST_DIR"/exec-tests-go.sh 'alpine-lfs-go-corehookspath' "$@"
