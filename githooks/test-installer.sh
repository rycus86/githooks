#!/bin/sh

REPO_DIR=$(git rev-parse --show-toplevel)

set -e

die() {
    echo "!! " "$@" >&2
    exit 1
}

cleanUp() {
    if [ -d "$tmp" ]; then
        rm -rf "$tmp"
    fi
}

tmp=$(mktemp -d)

trap cleanUp EXIT INT TERM

currentTag=$(git describe --tags --abbrev=0)
githooksServer="/var/lib/githooks-server"

cat <<EOF | docker build --force-rm -t githooks:go-installer-test -f - "$REPO_DIR"
FROM golang:1.15.3-alpine
RUN apk add --no-cache git git-lfs bash

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD ./.git $githooksServer/.git
RUN cd $githooksServer/ && rm -rf $githooksServer/.git/hooks && git reset --hard && git status

ADD githooks /var/lib/githooks/githooks

# Commit everything
RUN echo "Make test gitrepo to clone from ..." && \
    cd /var/lib/githooks && git init >/dev/null 2>&1 && \
    git add . >/dev/null 2>&1 && \
    git commit -a -m "Initial release" >/dev/null 2>&1 && \
    git tag "$currentTag-test" >/dev/null 2>&1 && \
    git commit -a --allow-empty -m "Empty to reset to trigger update" >/dev/null 2>&1

# Build binaries
RUN cd /var/lib/githooks/githooks && ./clean.sh
RUN /var/lib/githooks/githooks/build.sh -tags debug,mock
RUN cp /var/lib/githooks/githooks/bin/installer /var/lib/githooks/installer

RUN /var/lib/githooks/installer --clone-url $githooksServer \
                                --clone-branch feature/go-refactoring \
                                --build-from-source
EOF
