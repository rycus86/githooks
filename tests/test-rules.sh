#!/bin/sh

cat <<EOF | docker build --force-rm -t githooks:test-rules -
FROM alpine
RUN apk add --no-cache git curl python3
RUN curl -fsSL https://github.com/mvdan/sh/releases/download/v3.6.0/shfmt_v3.6.0_linux_amd64 -o /usr/local/bin/shfmt \
    && chmod +x /usr/local/bin/shfmt \
    && shfmt --version
RUN T=$(mktemp); curl -fsSL https://github.com/koalaman/shellcheck/releases/download/v0.9.0/shellcheck-v0.9.0.linux.x86_64.tar.xz -o "\\\$T" \
    && tar -xf "\\\$T" --strip-components=1 -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/shellcheck \
    && shellcheck --version
EOF

FAILURES=""

run_pre_commit_test() {
    if ! docker run --rm -v "$(pwd)":/data -w /data githooks:test-rules sh ".githooks/pre-commit/$1"; then
        FAILURES="$FAILURES
  - $1 failed"
    fi
}

run_pre_commit_test no-single-quote
run_pre_commit_test no-tabs
run_pre_commit_test no-todo-or-fixme
run_pre_commit_test shfmt
run_pre_commit_test shellcheck
run_pre_commit_test shellcheck-ignore-format
run_pre_commit_test has-shell-function-comments
run_pre_commit_test cli-docs-up-to-date

if [ -n "$FAILURES" ]; then
    echo "The following pre-commit checks had problems: $FAILURES"
    exit 1
else
    echo "All pre-commit hooks have been verified"
fi
