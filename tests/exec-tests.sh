#!/bin/sh
IMAGE_TYPE="$1"

cat <<EOF | docker build --force-rm -t githooks:"$IMAGE_TYPE" -f - .
FROM githooks:${IMAGE_TYPE}-base

ADD base-template.sh install.sh uninstall.sh cli.sh /var/lib/githooks/

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD tests/exec-steps.sh tests/step-* /var/lib/tests/

# Change the base template so we can pass in the hook name and accept flags
RUN sed -i 's|HOOK_NAME=.*|HOOK_NAME=\${HOOK_NAME:-\$(basename "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|HOOK_FOLDER=.*|HOOK_FOLDER=\${HOOK_FOLDER:-\$(dirname "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|ACCEPT_CHANGES=.*|ACCEPT_CHANGES=\${ACCEPT_CHANGES}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|read -r ACCEPT_CHANGES|echo "Accepted: \$ACCEPT_CHANGES" # disabled for tests: read -r ACCEPT_CHANGES|' /var/lib/githooks/base-template.sh

RUN sh /var/lib/tests/exec-steps.sh
EOF

RESULT=$?
docker rmi githooks:"$IMAGE_TYPE"
docker rmi githooks:"${IMAGE_TYPE}-base"
exit $RESULT
