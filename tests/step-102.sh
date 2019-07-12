#!/bin/sh
# Test:
#   Cli tool: run a download using a tool

if ! sh /var/lib/githooks/install.sh; then
    echo "! Failed to execute the install script"
    exit 1
fi

mkdir -p /tmp/test102 && cd /tmp/test102 || exit 2

git init || exit 3

mkdir tool
cat <<EOF >tool/run
#!/bin/sh
echo "# Version: testing.version" > "\$2"
echo "echo 'Written \$1 for testing'" >> "\$2"
echo "\$2" > /tmp/test102/output
echo "Mock update finished"
EOF

if ! sh /var/lib/githooks/cli.sh tools register download ./tool; then
    echo "! Failed to register download tool"
    exit 4
fi

if ! sh /var/lib/githooks/cli.sh update force; then
    echo "! Failed to run forced update"
    exit 5
fi

if [ ! -f /tmp/test102/output ]; then
    echo "! Output file not found"
    exit 6
fi

if ! grep -q "Written install.sh for testing" "$(cat /tmp/test102/output)"; then
    echo "! Expected output not found"
    exit 7
fi

if ! sh /var/lib/githooks/cli.sh tools unregister download; then
    echo "! Failed to unregister tool"
    exit 8
fi

if [ -e ~/".githooks/tools/download" ]; then
    echo "! Unregister unsuccessful"
    exit 9
fi
