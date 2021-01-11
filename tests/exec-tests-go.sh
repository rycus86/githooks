#!/bin/sh
IMAGE_TYPE="$1"
shift
# shellcheck disable=SC2124
SEQUENCE="$@"

[ -z "$SEQUENCE" ] && SEQUENCE="{001..120}"

if echo "$IMAGE_TYPE" | grep -q "\-user"; then
    OS_USER="test"
else
    OS_USER="root"
fi

cat <<EOF | docker build --force-rm -t githooks:"$IMAGE_TYPE" -f - .
FROM githooks:${IMAGE_TYPE}-base

RUN git config --global user.email "githook@test.com" && \\
    git config --global user.name "Githook Tests" && \\
    git config --global init.defaultBranch main

ENV GITHOOKS_TEST_REPO=/var/lib/githooks
ENV GITHOOKS_BIN_DIR=/var/lib/githooks/githooks/bin

# Add sources
COPY --chown=${OS_USER}:${OS_USER} githooks \${GITHOOKS_TEST_REPO}/githooks
RUN sed -i -E 's/^bin//' \${GITHOOKS_TEST_REPO}/githooks/.gitignore # We use the bin folder
ADD .githooks/README.md \${GITHOOKS_TEST_REPO}/.githooks/README.md
ADD examples \${GITHOOKS_TEST_REPO}/examples

RUN echo "Make test gitrepo to clone from ..." && \\
    cd \${GITHOOKS_TEST_REPO} && git init >/dev/null 2>&1 && \\
    git add . >/dev/null 2>&1 && \\
    git commit -a -m "Before build" >/dev/null 2>&1

# Build binaries for v9.9.0-test.
#################################
RUN cd \${GITHOOKS_TEST_REPO}/githooks && \\
    git tag "v9.9.0-test" >/dev/null 2>&1 && \\
     ./scripts/clean.sh && \\
    ./scripts/build.sh --build-flags "-tags debug,mock" && \\
    ./bin/installer --version
RUN echo "Commit build v9.9.0-test to repo ..." && \\
    cd \${GITHOOKS_TEST_REPO} && \\
    git add . >/dev/null 2>&1 && \\
    git commit -a --allow-empty -m "Version 9.9.0-test" >/dev/null 2>&1 && \\
    git tag -f "v9.9.0-test"

# Build binaries for v9.9.1-test.
#################################
RUN cd \${GITHOOKS_TEST_REPO}/githooks && \\
    git commit -a --allow-empty -m "Before build" >/dev/null 2>&1 && \\
    git tag -f "v9.9.1-test" && \\
    ./scripts/clean.sh && \\
    ./scripts/build.sh --build-flags "-tags debug,mock" && \\
    ./bin/installer --version
RUN echo "Commit build v9.9.1-test to repo ..." && \\
    cd \${GITHOOKS_TEST_REPO} && \\
    git commit -a --allow-empty -m "Version 9.9.01test" >/dev/null 2>&1 && \\
    git tag -f "v9.9.1-test"

# Copy the tests somewhere different
ADD tests /var/lib/tests/
RUN if [ -n "\${EXTRA_INSTALL_ARGS}" ]; then \\
        sed -i -E 's|(.*)/installer\"|\1/installer" \${EXTRA_INSTALL_ARGS}|g' /var/lib/tests/step-* ; \\
    fi

# Always don't delete LFS Hooks (for testing, default is unset, but cumbersome for tests)
RUN git config --global githooks.deleteDetectedLFSHooks "n"

${ADDITIONAL_INSTALL_STEPS:-}

RUN echo "Git version: \$(git --version)"

RUN sh /var/lib/tests/exec-steps-go.sh --sequence $SEQUENCE
EOF

RESULT=$?
docker rmi githooks:"$IMAGE_TYPE"
docker rmi githooks:"${IMAGE_TYPE}-base"
exit $RESULT
