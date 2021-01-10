#!/bin/sh

TEST_DIR=$(dirname "$0")

cat <<EOF | docker build --force-rm -t githooks:whitespaces-base -
FROM alpine
RUN apk add --no-cache git curl ca-certificates
RUN mkdir -p "/root/whitespace folder"
ENV HOME="/root/whitespace folder"
EOF

export ADDITIONAL_INSTALL_STEPS='
# add a space in paths and wrap in double-quotes
RUN find /var/lib/tests -name "*.sh" -exec sed -i -E "s|/tmp/test([0-9.]+)|\"/tmp/test \1\"|g" {} \;
# remove the double-quotes if the path is the only thing on the whole line
RUN find /var/lib/tests -name "*.sh" -exec sed -i -E "s|^\"/tmp/test([^\"]+)\"|/tmp/test\1|g" {} \;
'

exec sh "$TEST_DIR"/exec-tests.sh 'whitespaces' "$@"
