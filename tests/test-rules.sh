#!/bin/sh

cat <<EOF | docker build --force-rm -t githooks:test-rules -
FROM alpine
RUN apk add --no-cache git curl python
RUN curl -fsSL https://github.com/mvdan/sh/releases/download/v2.6.4/shfmt_v2.6.4_linux_amd64 -o /usr/local/bin/shfmt \
    && chmod +x /usr/local/bin/shfmt \
    && shfmt --version
RUN curl -fsSL https://shellcheck.storage.googleapis.com/shellcheck-v0.6.0.linux-x86_64 -o /usr/local/bin/shellcheck \
    && chmod +x /usr/local/bin/shellcheck \
    && shellcheck --version
EOF

FAILURES=""

run_pre_commit_test() {
    if ! docker run --rm -it -v "$(pwd)":/data -w /data githooks:test-rules sh ".githooks/pre-commit/$1"; then
        FAILURES="$FAILURES
  - $1 failed"
    fi
}

run_pre_commit_test no-single-quote
run_pre_commit_test no-tabs
run_pre_commit_test no-todo-or-fixme
run_pre_commit_test shfmt
run_pre_commit_test shellcheck
run_pre_commit_test has-shell-function-comments
run_pre_commit_test cli-docs-up-to-date

if [ -n "$FAILURES" ]; then
    echo "The following pre-commit checks had problems: $FAILURES"
    exit 1
else
    echo "All pre-commit hooks have been verified"
fi
