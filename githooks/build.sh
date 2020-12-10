#!/bin/sh
DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

set -e
set -u

# shellcheck disable=SC2124
buildFlags="$@"

cd "$DIR"
buildVersion=$(git describe --tags --abbrev=6 --always)

# shellcheck disable=SC2086
GOPATH="$DIR/.go" \
    GOBIN="$DIR/bin" \
    go install \
    -ldflags="-X 'rycus86/githooks/hooks.BuildVersion=$buildVersion'" \
    -tags debug $buildFlags ./...
