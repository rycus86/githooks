#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:arch-base -
FROM archlinux/base
RUN echo Y | pacman -Sy git gawk
EOF

exec sh "$TEST_DIR"/exec-tests.sh 'arch'
