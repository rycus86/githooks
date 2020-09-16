#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

GOPATH="$DIR/.go" \
    GOBIN="$DIR/bin" \
    go install ./...
