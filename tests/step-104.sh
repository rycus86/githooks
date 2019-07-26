#!/bin/sh
# Test:
#   Cli tool: run the dialog tool

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test104/.githooks/pre-commit &&
    echo 'echo "Hello"' >/tmp/test104/.githooks/pre-commit/testing &&
    cd /tmp/test104 &&
    git init ||
    exit 1

mkdir tool
cat <<EOF >tool/run
#!/bin/sh
echo "Written for testing" > /tmp/test104/output
# printf "Dialog Tool Prompt: %s %s [%s]:" "\$1" "\$2" "\$3"
echo "Y" # Return always Yes
EOF

if ! git hooks tools register dialog ./tool; then
    echo "! Failed to register dialog tool"
    exit 4
fi

# Trigger dialog, by triggering the trust prompt
if ! git hooks config deny trusted; then
    echo "! Failed to set trust setting"
    exit 5
fi

echo "A" >A && git add A || exit 6

if ! git commit -m "Test"; then
    echo "! Commit not succesful"
    exit 7
fi

if ! grep -q "Written for testing" /tmp/test104/output; then
    echo "! Expected output not found"
    exit 8
fi

# Test dialog tool fallback

cat <<EOF >tool/run
#!/bin/sh
echo "Written for testing" > /tmp/test104/output-fail
# printf "Dialog Tool Prompt: %s %s [%s]:" "\$1" "\$2" "\$3"
echo "Y" # Return always Yes
exit 1 # fall back to stdin prompt...
EOF

if ! git hooks tools register dialog ./tool; then
    echo "! Failed to register dialog tool"
    exit 9
fi

echo "A" >>A || exit 10
rm -rf .git/.githooks.checksum || true
OUTPUT=$(git commit -a -m "Test2" 2>&1)
if ! echo "$OUTPUT" | grep -q "Do you accept the changes?"; then
    echo "! Expected fall back prompt not found"
    exit 11
fi

if ! grep -q "Written for testing" /tmp/test104/output-fail; then
    echo "! Expected output not found"
    exit 8
fi

if ! git hooks tools unregister dialog; then
    echo "! Failed to unregister tool"
    exit 12
fi

if [ -e ~/".githooks/tools/dialog" ]; then
    echo "! Unregister unsuccessful"
    exit 13
fi
