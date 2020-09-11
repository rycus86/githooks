#!/bin/sh

RUN_DIR="${RUN_DIR:-"$PWD"}"

TEST_STEP="$1"

# Test only sepcific tests
if [ -n "$TEST_STEP" ]; then
    STEPS_TO_RUN="step-${TEST_STEP}.sh"
else
    STEPS_TO_RUN="step-*"
fi

# Build a Docker image on top of kcov with our scripts
cat <<EOF | docker build --force-rm -t githooks:coverage -f - .
FROM kcov/kcov:latest

RUN echo 'deb http://deb.debian.org/debian stretch main' >> /etc/apt/sources.list \
    && (apt-get update || true) \
    && apt-get install -y git git-lfs

ADD base-template.sh base-template-wrapper.sh install.sh uninstall.sh cli.sh /var/lib/githooks/
RUN chmod +x /var/lib/githooks/*.sh
ADD .githooks/README.md /var/lib/githooks/.githooks/README.md
ADD examples /var/lib/githooks/examples

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD tests/exec-steps.sh tests/${STEPS_TO_RUN} /var/lib/tests/

# Some fixup below:
# We overwrite the download to use the current install.sh in all scripts
RUN \\
# Make sure we're using Bash for kcov
    find /var/lib -name '*.sh' -exec sed -i -E 's|#!/bin/sh|#!/bin/bash|g' {} \\; && \\
    # at the beginnig of line
    find /var/lib -name '*.sh' -exec sed -i -E 's|^( *)sh /|\1bash /|g' {} \\; && \\
    find /var/lib -name '*.sh' -exec sed -i -E 's|^( *)sh "|\1bash "|g' {} \\; && \\
    find /var/lib -name '*.sh' -exec sed -i -E 's|^( *)sh ~/|\1bash /home/coverage/|g' {} \\; && \\
    # in between line
    find /var/lib -name '*.sh' -exec sed -i -E 's|( +)sh /|\1bash /|g' {} \\; && \\
    find /var/lib -name '*.sh' -exec sed -i -E 's|( +)sh "|\1bash "|g' {} \\; && \\
    find /var/lib -name '*.sh' -exec sed -i -E 's|( +)sh ~/|\1bash /home/coverage/|g' {} \\; && \\
    # git hooks alias
    find /var/lib -name '*.sh' -exec sed -i 's|"!sh |"!bash |g' {} \\; && \\
# Revert changed shell script filenames
    find /var/lib -name '*.sh' -exec sed -E -i "s|/var/lib/githooks/([a-z-]+)\\.bash|/var/lib/githooks/\\1.sh|g" {} \\; && \\
# Change any \`git hooks\` invocation to the shell script for better code coverage
    find /var/lib/tests/ -name '*.sh' -exec sed -i -E 's|([^"])git +hooks|\1bash /home/coverage/.githooks/release/cli.sh|g' {} \\; && \\
    find /var/lib/tests/ -name '*.sh' -exec sed -i -E 's|^( +)git +hooks|\1bash /home/coverage/.githooks/release/cli.sh|g' {} \\; && \\
# Change multiline echos to line-wise echos for kcov
    sed -i -E '/echo "$/,/^"/{  s/echo "/echo ""/ ; s/^"$/echo ""/  ;  /^\s*echo/! { s/(.*)/echo "\1"/ } }' /var/lib/githooks/cli.sh && \\
# Do not use the terminal in tests
    sed -i 's|</dev/tty||g' /var/lib/githooks/install.sh && \\
# Change the base template so we can pass in the hook name and accept flags
    sed -i -E 's|GITHOOKS_RUNNER=(.*)|GITHOOKS_RUNNER=\1; GITHOOKS_RUNNER="\${GITHOOKS_RUNNER:-/var/lib/githooks/base-template.sh}"|' /var/lib/githooks/base-template-wrapper.sh && \\
    sed -i -E 's|HOOK_FOLDER=(.*)|HOOK_FOLDER="\${HOOK_FOLDER:-\1}"|' /var/lib/githooks/base-template.sh && \\
    sed -i -E 's|HOOK_NAME=(.*)|HOOK_NAME="\${HOOK_NAME:-\1}"|' /var/lib/githooks/base-template.sh && \\
    sed -i 's|ACCEPT_CHANGES=|ACCEPT_CHANGES=\${ACCEPT_CHANGES}|' /var/lib/githooks/base-template.sh && \\
    sed -i 's%read -r "\$VARIABLE"%eval "\$VARIABLE=\\\\\$\$(eval echo "\\\\\$VARIABLE")" # disabled for tests: read -r "\$VARIABLE"%' /var/lib/githooks/base-template.sh && \\
    sed -i -E 's|GITHOOKS_CLONE_URL="http.*"|GITHOOKS_CLONE_URL="/var/lib/githooks"|' /var/lib/githooks/cli.sh /var/lib/githooks/base-template.sh /var/lib/githooks/install.sh

# Commit everything
RUN echo "Make test gitrepo to clone from ..." && \
    cd /var/lib/githooks && git init && \
    git add . && \
    git commit -a -m "Initial release" && \
    git commit -a --allow-empty -m "Empty to reset to trigger update"

RUN useradd -ms /bin/bash coverage
RUN chown -R coverage:coverage /var /usr/share/git-core

USER coverage
WORKDIR /home/coverage
RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"


## Debugging #########################################
# If you run into failing coverage, run all tests, and
# inspect the failing test.
# Uncomment the kvoc run below!

# RUN mkdir -p ~/cover && cp "/var/lib/tests/"${STEPS_TO_RUN} ~/cover
# RUN sh /var/lib/tests/exec-steps.sh

######################################################

RUN kcov \
    --coveralls-id="$TRAVIS_JOB_ID" \
    --include-pattern="/home/coverage/.githooks/release" \
    ~/cover \
    "/var/lib/tests/exec-steps.sh"
EOF

# shellcheck disable=SC2181
if [ $? -ne 0 ]; then
    exit 1
fi

# Make sure we delete the previous run results
docker run --user root --rm --security-opt seccomp=unconfined \
    -v "${RUN_DIR}/cover":/cover \
    --entrypoint sh \
    githooks:coverage \
    -c 'rm -rf /cover/*'

# Collect the coverage info
docker run --user root --rm --security-opt seccomp=unconfined \
    -v "${RUN_DIR}/cover":/cover \
    githooks:coverage \
    bash -c 'cp -r /home/coverage/cover /cover/'
