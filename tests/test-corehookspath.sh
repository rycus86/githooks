#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:corehookspath-base -
FROM alpine
RUN apk add --no-cache git curl ca-certificates
ENV EXTRA_INSTALL_ARGS --use-core-hookspath
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'corehookspath'
