#!/bin/sh
IMAGE_TYPE="$1"
TEST_STEP="$2"
# This parameter prevent the trust of the repo if a marker is found, user shall run git hooks trust...
export CI=true

# Test only sepcific tests
if [ -n "$TEST_STEP" ]; then
    STEPS_TO_RUN="step-${TEST_STEP}.sh"
else
    STEPS_TO_RUN="step-*"
fi

if echo "$IMAGE_TYPE" | grep -q "\-user"; then
    OS_USER="test"
else
    OS_USER="root"
fi

cat <<EOF | docker build --force-rm -t githooks:"$IMAGE_TYPE" -f - .
FROM githooks:${IMAGE_TYPE}-base

COPY --chown=${OS_USER}:${OS_USER} base-template.sh base-template-wrapper.sh install.sh uninstall.sh cli.sh /var/lib/githooks/
RUN chmod +x /var/lib/githooks/*.sh
ADD .githooks/README.md /var/lib/githooks/.githooks/README.md
ADD examples /var/lib/githooks/examples

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests" && \
    git config --global init.defaultBranch master

ADD tests/exec-steps.sh tests/${STEPS_TO_RUN} /var/lib/tests/

# Do not use the terminal in tests
RUN sed -i 's|</dev/tty||g' /var/lib/githooks/install.sh && \\
    # Change the base template so we can pass in the hook name and accept flags
    sed -i -E 's|GITHOOKS_RUNNER=(.*)|GITHOOKS_RUNNER=\1; GITHOOKS_RUNNER="\${GITHOOKS_RUNNER:-/var/lib/githooks/base-template.sh}"|' /var/lib/githooks/base-template-wrapper.sh && \\
    sed -i -E 's|HOOK_FOLDER=(.*)|HOOK_FOLDER="\${HOOK_FOLDER:-\1}"|' /var/lib/githooks/base-template.sh && \\
    sed -i -E 's|HOOK_NAME=(.*)|HOOK_NAME="\${HOOK_NAME:-\1}"|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|ACCEPT_CHANGES=|ACCEPT_CHANGES=\${ACCEPT_CHANGES}|'  /var/lib/githooks/base-template.sh && \\
    sed -i 's%read -r "\$VARIABLE"%eval "\$VARIABLE=\\\\\$\$(eval echo "\\\\\$VARIABLE")" # disabled for tests: read -r "\$VARIABLE"%' /var/lib/githooks/base-template.sh && \\
    sed -i -E 's|GITHOOKS_CLONE_URL="http.*"|GITHOOKS_CLONE_URL="/var/lib/githooks"|' /var/lib/githooks/cli.sh /var/lib/githooks/base-template.sh /var/lib/githooks/install.sh && \\
# Conditionally allow file:// for local shared hooks simulating http:// protocol
    sed -i -E 's|if(.*grep.*file://.*)|if [ "\$(git config --global githooks.testingTreatFileProtocolAsRemote)" != "true" ] \&\& \1|' /var/lib/githooks/cli.sh /var/lib/githooks/base-template.sh /var/lib/githooks/install.sh
# Commit everything
RUN echo "Make test gitrepo to clone from ..." && \
    cd /var/lib/githooks && git init && \
    git add . && \
    git commit -a -m "Initial release" && \
    git commit -a --allow-empty -m "Empty to reset to trigger update"


RUN if [ -n "\${EXTRA_INSTALL_ARGS}" ]; then \\
        sed -i -E "s|sh (.*)/install.sh|sh \1/install.sh \${EXTRA_INSTALL_ARGS}|g" /var/lib/tests/step-* ; \\
    fi

# Always don't delete LFS Hooks (for testing, default is unset, but cumbersome for tests)
RUN git config --global githooks.deleteDetectedLFSHooks "n"

${ADDITIONAL_INSTALL_STEPS:-}

RUN CI=${CI} sh /var/lib/tests/exec-steps.sh
EOF

RESULT=$?
docker rmi githooks:"$IMAGE_TYPE"
docker rmi githooks:"${IMAGE_TYPE}-base"
exit $RESULT
