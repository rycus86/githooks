#!/bin/sh
IMAGE_TYPE="$1"

# Test only sepcific tests
if [ -n "$TEST_STEP" ]; then
    STEPS_TO_RUN="step-${TEST_STEP}.sh"
else
    STEPS_TO_RUN="step-*"
fi

# Switch to mock the download of any install.sh and use the current implementation
if [ -n "$MOCK_DOWNLOAD" ]; then
    echo "Execute tests by mocking the download of the install.sh script!"
fi

cat <<EOF | docker build --force-rm -t githooks:"$IMAGE_TYPE" -f - .
FROM githooks:${IMAGE_TYPE}-base

ADD base-template.sh install.sh uninstall.sh cli.sh /var/lib/githooks/
ADD examples /var/lib/githooks/examples

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD tests/exec-steps.sh tests/${STEPS_TO_RUN} /var/lib/tests/

# Do not use the terminal in tests
RUN sed -i 's|</dev/tty||g' /var/lib/githooks/install.sh && \\
# Change the base template so we can pass in the hook name and accept flags
    sed -i -E 's|echo.*Hook not run inside a git repository.*|CURRENT_GIT_DIR=".git"|' /var/lib/githooks/base-template.sh /var/lib/githooks/install.sh && \\
    sed -i -E 's|HOOK_NAME=.*|HOOK_NAME=\${HOOK_NAME:-\$(basename "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i -E 's|HOOK_FOLDER=.*|HOOK_FOLDER=\${HOOK_FOLDER:-\$(dirname "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|ACCEPT_CHANGES=|ACCEPT_CHANGES=\${ACCEPT_CHANGES}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's%read -r "\$VARIABLE"%eval "\$VARIABLE=\\\\\$\$(eval echo "\\\\\$VARIABLE")" # disabled for tests: read -r "\$VARIABLE"%' /var/lib/githooks/base-template.sh

RUN if [ -n "$MOCK_DOWNLOAD" ]; then \\
    # We overwrite the download to use the current install.sh in all scripts
    sed -i -E 's@(curl|wget).*(DOWNLOAD_URL|OUTPUT_FILE).*(DOWNLOAD_URL|OUTPUT_FILE).*@cp -f /var/lib/githooks/install.sh "\$OUTPUT_FILE"@g' \\
        /var/lib/githooks/install.sh \\
        /var/lib/githooks/cli.sh  \\
        /var/lib/githooks/base-template.sh ; \\
    fi

RUN if [ -n "\${EXTRA_INSTALL_ARGS}" ]; then \\
        sed -i "s|sh /var/lib/githooks/install.sh|sh /var/lib/githooks/install.sh \${EXTRA_INSTALL_ARGS}|g" /var/lib/tests/step-* ; \\
        sed -i -E "s|sh -c (.*) -- |sh -c \\1 -- \${EXTRA_INSTALL_ARGS} |g" /var/lib/tests/step-* ; \\
    fi

# Always don't delete LFS Hooks (for testing, default is unset, but cumbersome for tests)
RUN git config --global githooks.deleteDetectedLFSHooks "n"

${ADDITIONAL_INSTALL_STEPS:-}

RUN sh /var/lib/tests/exec-steps.sh
EOF

RESULT=$?
docker rmi githooks:"$IMAGE_TYPE"
docker rmi githooks:"${IMAGE_TYPE}-base"
exit $RESULT
