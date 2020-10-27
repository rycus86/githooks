#!/bin/bash
REPO_DIR=$(git rev-parse --show-toplevel)

file="$REPO_DIR/tests/step-$1.sh"
if [ "$2" = "-r" ]; then
    git checkout HEAD "$file"
fi

perl -i -0777 -pe 's@HOOK_NAME=([^ ]+).*\n?.*HOOK_FOLDER=([^ ]+)\s*\\?\n?((?:(?:.*\n)*?).*)sh\s+(.*)-wrapper\.sh@\3\4.sh \2/\1@g' "$file"
perl -i -0777 -pe 's@.sh \$\(pwd\)@.sh "\$(pwd)"@g' "$file"

shfmt -p -w -i 4 "$file"
