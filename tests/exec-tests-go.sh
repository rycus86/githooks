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
    git config --global user.name "Githook Tests"

# Add sources
COPY --chown=${OS_USER}:${OS_USER} base-template-wrapper.sh cli.sh /var/lib/githooks/
RUN chmod +x /var/lib/githooks/*.sh
ADD githooks /var/lib/githooks/githooks
RUN sed -i -E 's/^bin//' /var/lib/githooks/githooks/.gitignore # We use the bin folder
ADD .githooks/README.md /var/lib/githooks/.githooks/README.md
ADD examples /var/lib/githooks/examples

RUN echo "Make test gitrepo to clone from ..." && \\
    cd /var/lib/githooks && git init >/dev/null 2>&1 && \\
    git add . >/dev/null 2>&1 && \\
    git commit -a -m "Before build" >/dev/null 2>&1

ENV GITHOOKS_BIN_DIR=/var/lib/githooks/githooks/bin

# Do not use the terminal in tests
RUN sed -i -E 's|GITHOOKS_CLONE_URL="http.*"|GITHOOKS_CLONE_URL="/var/lib/githooks"|' /var/lib/githooks/cli.sh && \\
    # Conditionally allow file:// for local shared hooks simulating http:// protocol
    sed -i -E 's|if(.*grep.*file://.*)|if [ "\$(git config --global githooks.testingTreatFileProtocolAsRemote)" != "true" ] \&\& \1|' /var/lib/githooks/cli.sh

# @todo: Remove this when cli is finished...
RUN sed -i -E 's|sh -s -- (.*) .+INSTALL_SCRIPT"|"\$INSTALL_SCRIPT" \1|g' /var/lib/githooks/cli.sh

# Build binaries for v9.9.0-test.
#################################
RUN cd /var/lib/githooks/githooks && \\
    git tag "v9.9.0-test" >/dev/null 2>&1 && \\
     ./scripts/clean.sh && \\
    ./scripts/build.sh --build-flags "-tags debug,mock" && \\
    cp ./bin/installer ../install.sh && \\
    ./bin/installer --version
RUN echo "Commit build v9.9.0-test to repo ..." && \\
    cd /var/lib/githooks && \\
    git add . >/dev/null 2>&1 && \\
    git commit -a --allow-empty -m "Version 9.9.0-test" >/dev/null 2>&1 && \\
    git tag -f "v9.9.0-test"

# Build binaries for v9.9.1-test.
#################################
RUN cd /var/lib/githooks/githooks && \\
    git commit -a --allow-empty -m "Before build" >/dev/null 2>&1 && \\
    git tag -f "v9.9.1-test" && \\
    ./scripts/clean.sh && \\
    ./scripts/build.sh --build-flags "-tags debug,mock" && \\
    cp ./bin/installer ../install.sh && \\
    ./bin/installer --version
RUN echo "Commit build v9.9.1-test to repo ..." && \\
    cd /var/lib/githooks && \\
    git commit -a --allow-empty -m "Version 9.9.01test" >/dev/null 2>&1 && \\
    git tag -f "v9.9.1-test"

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
