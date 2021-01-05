#!/bin/sh
DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
GO_SRC="$DIR/.."

set -e
set -u

die() {
    echo "!! " "$@" >&2
    exit 1
}

go run -mod=vendor "$GO_SRC/tools/generate-doc.go"
