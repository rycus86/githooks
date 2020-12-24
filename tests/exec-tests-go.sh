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
COPY --chown=${OS_USER}:${OS_USER} base-template-wrapper.sh install.sh uninstall.sh cli.sh /var/lib/githooks/
RUN chmod +x /var/lib/githooks/*.sh
ADD githooks /var/lib/githooks/githooks
ADD .githooks/README.md /var/lib/githooks/.githooks/README.md
ADD examples /var/lib/githooks/examples

RUN echo "Make test gitrepo to clone from ..." && \\
    cd /var/lib/githooks && git init >/dev/null 2>&1 && \\
    git add . >/dev/null 2>&1 && \\
    git commit -a -m "Before build" >/dev/null 2>&1 && \\
    git tag "v9.9.0-test" >/dev/null 2>&1

# Build binaries
RUN cd /var/lib/githooks/githooks && ./clean.sh
RUN /var/lib/githooks/githooks/build.sh --build-flags "-tags debug,mock"
# @todo remove once install is ready, replace...
RUN cp /var/lib/githooks/githooks/bin/runner /var/lib/githooks/base-template.sh

# Do not use the terminal in tests
RUN sed -i 's|</dev/tty||g' /var/lib/githooks/install.sh && \\
    # Change the base template so we can pass in the hook name and accept flags
    sed -i -E 's|GITHOOKS_RUNNER=(.*)|GITHOOKS_RUNNER=\1; GITHOOKS_RUNNER="\${GITHOOKS_RUNNER:-/var/lib/githooks/base-template.sh}"|' /var/lib/githooks/base-template-wrapper.sh && \\
    sed -i -E 's|^exec (.*)"\$0"(.*)|if [ "\$1" = --mock-direct ]; then h="\$2"; shift 2; else h="\$0"; fi; exec \1"\$h"\2 |g' /var/lib/githooks/base-template-wrapper.sh && \\
    sed -i -E 's|GITHOOKS_CLONE_URL="http.*"|GITHOOKS_CLONE_URL="/var/lib/githooks"|' /var/lib/githooks/cli.sh /var/lib/githooks/install.sh && \\
    # Conditionally allow file:// for local shared hooks simulating http:// protocol
    sed -i -E 's|if(.*grep.*file://.*)|if [ "\$(git config --global githooks.testingTreatFileProtocolAsRemote)" != "true" ] \&\& \1|' /var/lib/githooks/cli.sh /var/lib/githooks/install.sh

# Commit everything
RUN echo "Commit build to repo ..." && \\
    cd /var/lib/githooks && \\
    git add . >/dev/null 2>&1 && \\
    git commit -a --allow-empty -m "Initial release" >/dev/null 2>&1 && \\
    git tag -f "v9.9.0-test" && \\
    git commit -a --allow-empty -m "Empty to reset to trigger update" >/dev/null 2>&1 && \\
    git tag -f "v9.9.1-test"

ADD tests/exec-steps.sh tests/step-* /var/lib/tests/
RUN if [ -n "\${EXTRA_INSTALL_ARGS}" ]; then \\
        sed -i -E "s|sh (.*)/install.sh|sh \1/install.sh \${EXTRA_INSTALL_ARGS}|g" /var/lib/tests/step-* ; \\
    fi

# Always don't delete LFS Hooks (for testing, default is unset, but cumbersome for tests)
RUN git config --global githooks.deleteDetectedLFSHooks "n"

${ADDITIONAL_INSTALL_STEPS:-}
RUN git --version

RUN sh /var/lib/tests/exec-steps.sh --sequence $SEQUENCE
EOF

RESULT=$?
docker rmi githooks:"$IMAGE_TYPE"
docker rmi githooks:"${IMAGE_TYPE}-base"
exit $RESULT
