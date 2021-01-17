#!/bin/sh
IMAGE_TYPE="$1"
shift
# shellcheck disable=SC2124
SEQUENCE="$@"

[ -n "$SEQUENCE" ] && SEQUENCE="--sequence $SEQUENCE"

if echo "$IMAGE_TYPE" | grep -q "\-user"; then
    OS_USER="test"
else
    OS_USER="root"
fi

cat <<EOF | docker build --force-rm -t githooks:"$IMAGE_TYPE" -f - .
FROM githooks:${IMAGE_TYPE}-base

ENV GH_TESTS="/var/lib/githooks-tests"
ENV GH_TEST_REPO="/var/lib/githooks"
ENV GH_TEST_TMP="/tmp"
ENV GH_TEST_BIN="/var/lib/githooks/githooks/bin"

${ADDITIONAL_PRE_INSTALL_STEPS:-}

RUN git config --global user.email "githook@test.com" && \\
    git config --global user.name "Githook Tests" && \\
    git config --global init.defaultBranch main && \\
    git config --global core.autocrlf false

# Add sources
COPY --chown=${OS_USER}:${OS_USER} githooks \${GH_TEST_REPO}/githooks
RUN sed -i -E 's/^bin//' \${GH_TEST_REPO}/githooks/.gitignore # We use the bin folder
ADD .githooks/README.md \${GH_TEST_REPO}/.githooks/README.md
ADD examples \${GH_TEST_REPO}/examples

RUN echo "Make test gitrepo to clone from ..." && \\
    cd \$GH_TEST_REPO && git init  2>&1 && \\
    git add . 2>&1 && \\
    git commit -a -m "Before build" 2>&1

# Build binaries for v9.9.0.
#################################
RUN cd \$GH_TEST_REPO/githooks && \\
    git tag "v9.9.0" >/dev/null 2>&1 && \\
     ./scripts/clean.sh && \\
    ./scripts/build.sh --build-flags "-tags debug,mock" && \\
    ./bin/installer --version
RUN echo "Commit build v9.9.0 to repo ..." && \\
    cd \$GH_TEST_REPO && \\
    git add . >/dev/null 2>&1 && \\
    git commit -a --allow-empty -m "Version 9.9.0" >/dev/null 2>&1 && \\
    git tag -f "v9.9.0"

# Build binaries for v9.9.1.
#################################
RUN cd \$GH_TEST_REPO/githooks && \\
    git commit -a --allow-empty -m "Before build" >/dev/null 2>&1 && \\
    git tag -f "v9.9.1" && \\
    ./scripts/clean.sh && \\
    ./scripts/build.sh --build-flags "-tags debug,mock" && \\
    ./bin/installer --version
RUN echo "Commit build v9.9.1 to repo ..." && \\
    cd \$GH_TEST_REPO && \\
    git commit -a --allow-empty -m "Version 9.9.1" >/dev/null 2>&1 && \\
    git tag -f "v9.9.1"

# Copy the tests somewhere different
ADD tests "\$GH_TESTS"
RUN if [ -n "\$EXTRA_INSTALL_ARGS" ]; then \\
        sed -i -E 's|(.*)/installer\"|\1/installer" \$EXTRA_INSTALL_ARGS|g' "\$GH_TESTS"/step-* ; \\
    fi

# Always don't delete LFS Hooks (for testing, default is unset, but cumbersome for tests)
RUN git config --global githooks.deleteDetectedLFSHooks "n"

${ADDITIONAL_INSTALL_STEPS:-}

RUN echo "Git version: \$(git --version)"

RUN sh "\$GH_TESTS"/exec-steps-go.sh $SEQUENCE
EOF

RESULT=$?
docker rmi githooks:"$IMAGE_TYPE"
docker rmi githooks:"${IMAGE_TYPE}-base"
exit $RESULT
