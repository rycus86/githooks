#!/bin/sh

if [ -z "$1" ]; then
    TESTS_TO_RUN="/var/lib/tests/exec-steps.sh"
else
    TESTS_TO_RUN="/var/lib/tests/${1}.sh"
fi

# Build a Docker image on top of kcov with our scripts
cat <<EOF | docker build --force-rm -t githooks:coverage -f - .
FROM ragnaroek/kcov:v33

ADD base-template.sh install.sh uninstall.sh cli.sh .githooks/README.md /var/lib/githooks/

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD tests/exec-steps.sh tests/step-* tests/replace-inline-content.py /var/lib/tests/

# Some fixup below:
# Make sure we're using Bash for kcov
RUN find /var/lib -name '*.sh' -exec sed -i 's|#!/bin/sh|#!/bin/bash|g' {} \\; && \\
    find /var/lib -name '*.sh' -exec sed -i 's|sh /|bash /|g' {} \\; && \\
    find /var/lib -name '*.sh' -exec sed -i 's|sh "|bash "|g' {} \\; && \\
# Revert changed shell script filenames
    find /var/lib -name '*.sh' -exec sed -E -i "s|/var/lib/githooks/([a-z-]+)\\.bash|/var/lib/githooks/\\1.sh|g" {} \\; && \\
# Replace the inline content with loading the source file
    python /var/lib/tests/replace-inline-content.py /var/lib/githooks && \\
# Change the base template so we can pass in the hook name and accept flags
    sed -i 's|HOOK_NAME=.*|HOOK_NAME=\${HOOK_NAME:-\$(basename "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|HOOK_FOLDER=.*|HOOK_FOLDER=\${HOOK_FOLDER:-\$(dirname "\$0")}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|ACCEPT_CHANGES=.*|ACCEPT_CHANGES=\${ACCEPT_CHANGES}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|read -r ACCEPT_CHANGES|echo "Accepted: \$ACCEPT_CHANGES" # disabled for tests: read -r ACCEPT_CHANGES|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|read -r TRUST_ALL_HOOKS|TRUST_ALL_HOOKS=\${TRUST_ALL_HOOKS} # disabled for tests: read -r TRUST_ALL_HOOKS|' /var/lib/githooks/base-template.sh
EOF

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    exit 1
fi

# Make sure we delete the previous run results
docker run --rm --security-opt seccomp=unconfined \
    -v "$PWD/cover":/cover \
    --entrypoint sh \
    githooks:coverage \
    -c 'rm -rf /cover/*'

# Run the actual tests and collect the coverage info
docker run --rm --security-opt seccomp=unconfined \
    -v "$PWD/cover":/cover \
    githooks:coverage \
    --coveralls-id="$TRAVIS_JOB_ID" \
    --include-pattern="/var/lib/githooks/" \
    /cover \
    "$TESTS_TO_RUN"
