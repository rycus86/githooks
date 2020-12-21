#!/bin/sh
DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

set -e
set -u

die() {
    echo "!! " "$@" >&2
    exit 1
}

BIN_DIR=""
BUILD_FLAGS=""

parseArgs() {
    prev_p=""
    for p in "$@"; do
        if [ "$p" = "--bin-dir" ]; then
            true
        elif [ "$prev_p" = "--bin-dir" ]; then
            BIN_DIR="$p"
        elif [ "$p" = "--build-flags" ]; then
            true
        elif [ "$prev_p" = "--build-flags" ]; then
            BUILD_FLAGS="$p"
        else
            echo "! Unknown argument \`$p\`" >&2
            return 1
        fi
        prev_p="$p"
    done
}

parseArgs "$@" || die "Parsing args failed."

cd "$DIR"
BUILD_VERSION=$(git describe --tags --abbrev=6 --always | sed -E "s/^v//")

export GOPATH="$DIR/.go"
export GOBIN="$DIR/bin"
if [ -n "$BIN_DIR" ]; then
    rm -rf "$BIN_DIR" || true
    export GOBIN="$BIN_DIR"
fi

go mod vendor
go generate -mod=vendor ./...

# shellcheck disable=SC2086
go install -mod=vendor \
    -ldflags="-X 'rycus86/githooks/hooks.BuildVersion=$BUILD_VERSION'" \
    -tags debug $BUILD_FLAGS ./...
