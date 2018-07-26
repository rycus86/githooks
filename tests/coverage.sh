#!/bin/sh

# Build a Docker image on top of kcov with our scripts
cat << EOF | docker build --force-rm -t githooks:coverage -f - .
FROM ragnaroek/kcov:v33

RUN apt-get update && apt-get install -y --no-install-recommends git

ADD base-template.sh install.sh uninstall.sh /var/lib/githooks/

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD tests/exec-steps.sh tests/step-* /var/lib/tests/

# Make sure we're using Bash for kcov
RUN find /var/lib -name '*.sh' -exec sed -i 's|#!/bin/sh|#!/bin/bash|g' {} \\;
RUN find /var/lib -name '*.sh' -exec sed -i 's|sh /|bash /|g' {} \\;
RUN find /var/lib -name '*.sh' -exec sed -i 's|sh "|bash "|g' {} \\;
EOF

# Run the actual tests and collect the coverage info
docker run --security-opt seccomp=unconfined \
    -v "$PWD/cover":/cover \
    githooks:coverage \
        --coveralls-id="$TRAVIS_JOB_ID" \
        --include-pattern="/var/lib/githooks/" \
        /cover \
        /var/lib/tests/exec-steps.sh
