#!/bin/sh
# Test:
#   Direct template execution: break if the previously moved hook is failing

# Pseudo installation.
mkdir -p ~/.githooks/release &&
    cp -r /var/lib/githooks/githooks/bin ~/.githooks ||
    exit 1
mkdir -p /tmp/test25 && cd /tmp/test25 || exit 1
git init || exit 1

mkdir -p .githooks &&
    mkdir -p .githooks/pre-commit &&
    echo 'echo "Direct execution" >> /tmp/test025.out' >>.githooks/pre-commit/test &&
    echo "#!/bin/sh" >.git/hooks/pre-commit.replaced.githook &&
    echo 'exit 1' >>.git/hooks/pre-commit.replaced.githook &&
    chmod +x .git/hooks/pre-commit.replaced.githook &&
    ~/.githooks/bin/runner "$(pwd)"/.git/hooks/pre-commit

if [ $? -ne 1 ]; then
    echo "! Expected the hooks to fail"
    exit 1
fi

printf 'patterns:\n   - "*.replaced.githook"' >.git/.githooks.ignore.yaml &&
    ~/.githooks/bin/runner "$(pwd)"/.git/hooks/pre-commit ||
    exit 1
