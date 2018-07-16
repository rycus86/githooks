#!/bin/sh
IMAGE_TYPE="$1"

cat << EOF | docker build --force-rm -t githooks:"$IMAGE_TYPE" -
FROM githooks:${IMAGE_TYPE}-base

RUN sh -c "\$(curl -fsSL https://raw.githubusercontent.com/rycus86/githooks/master/install.sh)" && \
    git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

WORKDIR /tmp/test1

RUN git init && \
    grep -q 'https://github.com/rycus86/githooks' .git/hooks/pre-commit

RUN mkdir -p .githooks/pre-commit && \
    echo 'echo "From githooks" > /tmp/hooktest' > .githooks/pre-commit/test && \
    (git commit -m '' ; exit 0) && \
    grep -q 'From githooks' /tmp/hooktest

RUN echo 'echo "Hook-1" >> /tmp/multitest' > .githooks/pre-commit/test1 && \
    echo 'echo "Hook-2" >> /tmp/multitest' > .githooks/pre-commit/test2 && \
    (git commit -m '' ; exit 0) && \
    grep -q 'Hook-1' /tmp/multitest && grep -q 'Hook-2' /tmp/multitest
EOF

RESULT=$?
docker rmi githooks:"$IMAGE_TYPE"
docker rmi githooks:"${IMAGE_TYPE}-base"
exit $RESULT
