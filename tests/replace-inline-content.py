"""
This small program replaces the inline base template
in the install script for a more sensible coverage percentage,
while keeping all lines at the same position.
"""

import re
import sys

CLI_HELP_PATTERN="(^ *echo \"$.+?^\")"

def process_cli_tool():
    base_folder = sys.argv[1]
    file_path = '%s/cli.sh' % base_folder

    contents = ''

    with open(file_path, 'r') as source:
        contents = source.read()

    for match in re.findall(CLI_HELP_PATTERN, contents, flags=re.MULTILINE | re.DOTALL):
        replaced = '\n'.join(['echo' if not l else 'echo "%s"' % l 
                              for l in match.splitlines()[1:-1]])
        replaced = 'echo\n%s\necho' % replaced

        contents = contents.replace(match, replaced)

    with open(file_path, 'w') as target:
        target.write(contents)

if __name__ == '__main__':
    process_cli_tool()
