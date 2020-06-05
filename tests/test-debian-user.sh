#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:debian-user-base -
FROM debian
RUN apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
        git-core ca-certificates && \
    adduser --disabled-password -u 1099 test && \
    mkdir -p /var/lib/githooks /var/backup/githooks /usr/share/git-core/templates/hooks && \
    chown -R test:test /var/lib/githooks /var/backup/githooks /usr/share/git-core
USER test
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'debian-user' "$@"
