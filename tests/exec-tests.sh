#!/bin/sh
IMAGE_TYPE="$1"

cat <<EOF | docker build --force-rm -t githooks:"$IMAGE_TYPE" -f - .
FROM githooks:${IMAGE_TYPE}-base

ADD base-template.sh install.sh uninstall.sh cli.sh /var/lib/githooks/
ADD examples /var/lib/githooks/examples

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD tests/exec-steps.sh tests/step-* /var/lib/tests/

# Do not use the terminal in tests
RUN sed -i 's|</dev/tty||g' /var/lib/githooks/install.sh && \\
# Change the base template so we can pass in the hook name and accept flags
    sed -i -E 's|HOOK_NAME=.*|HOOK_NAME=\${HOOK_NAME:-\$(basename "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i -E 's|HOOK_FOLDER=.*|HOOK_FOLDER=\${HOOK_FOLDER:-\$(dirname "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|ACCEPT_CHANGES=|ACCEPT_CHANGES=\${ACCEPT_CHANGES}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's%read -r "\$VARIABLE"%eval "\$VARIABLE=\\\\\$\$(eval echo "\\\\\$VARIABLE")" # disabled for tests: read -r "\$VARIABLE"%' /var/lib/githooks/base-template.sh
    
RUN if [ -n "\${EXTRA_INSTALL_ARGS}" ]; then \\
        sed -i "s|sh /var/lib/githooks/install.sh|sh /var/lib/githooks/install.sh \${EXTRA_INSTALL_ARGS}|g" /var/lib/tests/step-* ; \\
        sed -i -E "s|sh -c (.*) -- |sh -c \\1 -- \${EXTRA_INSTALL_ARGS} |g" /var/lib/tests/step-* ; \\
    fi

RUN sh /var/lib/tests/exec-steps.sh
EOF

RESULT=$?
docker rmi githooks:"$IMAGE_TYPE"
docker rmi githooks:"${IMAGE_TYPE}-base"
exit $RESULT
