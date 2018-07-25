#!/bin/sh
IMAGE_TYPE="$1"

cat << EOF | docker build --force-rm -t githooks:"$IMAGE_TYPE" -f - .
FROM githooks:${IMAGE_TYPE}-base

ADD install.sh /var/lib/githooks.sh
ADD uninstall.sh /var/lib/uninstall.sh

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD tests/step-* /var/lib/tests/

RUN for STEP in /var/lib/tests/step-*.sh; do \
        echo "> Executing "\$(basename "\$STEP") && \
        sh \$STEP && \
        sh /var/lib/uninstall.sh ; \
    done
EOF

RESULT=$?
docker rmi githooks:"$IMAGE_TYPE"
docker rmi githooks:"${IMAGE_TYPE}-base"
exit $RESULT
