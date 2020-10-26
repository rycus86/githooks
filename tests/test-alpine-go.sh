#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:alpine-lfs-go-base -
FROM alpine
RUN apk add --no-cache git git-lfs
RUN apk add --no-cache make musl-dev go

# Configure Go
ENV GOROOT /usr/lib/go
ENV GOPATH /go
ENV PATH /go/bin:$PATH
EOF

exec sh "$TEST_DIR"/exec-tests-go.sh 'alpine-lfs-go' "$@"
