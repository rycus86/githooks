#!/bin/sh
DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
GO_SRC="$DIR/.."

rm -rf "$GO_SRC/.go"
