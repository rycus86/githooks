#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:alpine-user-base -
FROM alpine
RUN apk add --no-cache git curl ca-certificates && \
    adduser -D -u 1099 test && \
    mkdir -p /var/lib/githooks /var/backup/githooks /usr/share/git-core/templates/hooks && \
    chown -R test:test /var/lib/githooks /var/backup/githooks /usr/share/git-core
USER test
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'alpine-user' "$@"
