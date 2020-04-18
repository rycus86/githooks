#!/bin/sh

RUN_DIR="${RUN_DIR:-"$PWD"}"

if [ -n "$1" ]; then
    STEPS_TO_RUN="$1.sh"
else
    STEPS_TO_RUN="step-*"
fi

# Build a Docker image on top of kcov with our scripts
cat <<EOF | docker build --force-rm -t githooks:coverage -f - .
FROM kcov/kcov:v33

RUN echo 'deb http://deb.debian.org/debian stretch main' >> /etc/apt/sources.list \
    && (apt-get update || true) \
    && apt-get install -y git

ADD base-template.sh install.sh uninstall.sh cli.sh /var/lib/githooks/
ADD .githooks/README.md /var/lib/githooks/.githooks/README.md
ADD examples /var/lib/githooks/examples

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD tests/exec-steps.sh tests/${STEPS_TO_RUN} tests/replace-inline-content.py /var/lib/tests/

# Some fixup below:
# We overwrite the download to use the current install.sh in all scripts
RUN \\
# Make sure we're using Bash for kcov
    find /var/lib -name '*.sh' -exec sed -i 's|#!/bin/sh|#!/bin/bash|g' {} \\; && \\
    find /var/lib -name '*.sh' -exec sed -i 's|sh /|bash /|g' {} \\; && \\
    find /var/lib -name '*.sh' -exec sed -i 's|sh "|bash "|g' {} \\; && \\
# Revert changed shell script filenames
    find /var/lib -name '*.sh' -exec sed -E -i "s|/var/lib/githooks/([a-z-]+)\\.bash|/var/lib/githooks/\\1.sh|g" {} \\; && \\
# Replace the inline content with loading the source file
    python /var/lib/tests/replace-inline-content.py /var/lib/githooks && \\
# Do not use the terminal in tests
    sed -i 's|</dev/tty||g' /var/lib/githooks/install.sh && \\
# Change the base template so we can pass in the hook name and accept flags
    sed -i 's|HOOK_NAME=.*|HOOK_NAME=\${HOOK_NAME:-\$(basename "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|HOOK_FOLDER=.*|HOOK_FOLDER=\${HOOK_FOLDER:-\$(dirname "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|ACCEPT_CHANGES=|ACCEPT_CHANGES=\${ACCEPT_CHANGES}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's%read -r "\$VARIABLE"%eval "\$VARIABLE=\\\\\$\$(eval echo "\\\\\$VARIABLE")" # disabled for tests: read -r "\$VARIABLE"%' /var/lib/githooks/base-template.sh && \\
    sed -i -E 's|GITHOOKS_CLONE_URL="http.*"|GITHOOKS_CLONE_URL="/var/lib/githooks"|' /var/lib/githooks/cli.sh /var/lib/githooks/base-template.sh /var/lib/githooks/install.sh 

# Commit everything
RUN echo "Make test gitrepo to clone from ..." && \
    cd /var/lib/githooks && git init && \
    git add . && \
    git commit -a -m "Initial release"
EOF

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    exit 1
fi

# Make sure we delete the previous run results
docker run --rm --security-opt seccomp=unconfined \
    -v "${RUN_DIR}/cover":/cover \
    --entrypoint sh \
    githooks:coverage \
    -c 'rm -rf /cover/*'

# Run the actual tests and collect the coverage info
docker run --rm --security-opt seccomp=unconfined \
    -v "${RUN_DIR}/cover":/cover \
    githooks:coverage \
    --coveralls-id="$TRAVIS_JOB_ID" \
    --include-pattern="/var/lib/githooks/" \
    /cover \
    "/var/lib/tests/exec-steps.sh"
