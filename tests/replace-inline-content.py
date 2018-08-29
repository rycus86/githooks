"""
This small program replaces the inline base template
in the install script for a more sensible coverage percentage,
while keeping all lines at the same position.
"""

import re
import sys

TEMPLATE_PATTERN="(.+)(BASE_TEMPLATE_CONTENT='[^']+')(.+)"
TEMPLATE_REPLACEMENT="BASE_TEMPLATE_CONTENT=$(cat %s/base-template.sh)"
CLI_TOOL_PATTERN="(.+)(CLI_TOOL_CONTENT='[^']+')(.+)"
CLI_TOOL_REPLACEMENT="CLI_TOOL_CONTENT=$(cat %s/cli.sh)"
README_PATTERN="(.+)(INCLUDED_README_CONTENT='[^']+')(.+)"
README_REPLACEMENT="INCLUDED_README_CONTENT=$(cat %s/README.md)"
CLI_HELP_PATTERN="(^ *echo \"$.+?^\")"

def process_install_script():
    base_folder = sys.argv[1]
    file_path = '%s/install.sh' % base_folder

    contents = ''

    with open(file_path, 'r') as source:
        contents = source.read()

    match = re.match(TEMPLATE_PATTERN, contents, flags=re.MULTILINE | re.DOTALL)
    before, template, after = match.groups()

    contents = '%s%s %s%s' % (
        before, 
        (TEMPLATE_REPLACEMENT % base_folder),
        '\n'.join(['#> %s' % line for line in template.splitlines()]),
        after
    )

    match = re.match(CLI_TOOL_PATTERN, contents, flags=re.MULTILINE | re.DOTALL)
    before, template, after = match.groups()

    contents = '%s%s %s%s' % (
        before, 
        (CLI_TOOL_REPLACEMENT % base_folder),
        '\n'.join(['#> %s' % line for line in template.splitlines()]),
        after
    )

    match = re.match(README_PATTERN, contents, flags=re.MULTILINE | re.DOTALL)
    before, template, after = match.groups()

    contents = '%s%s %s%s' % (
        before, 
        (README_REPLACEMENT % base_folder),
        '\n'.join(['#> %s' % line for line in template.splitlines()]),
        after
    )
    
    with open(file_path, 'w') as target:
        target.write(contents)

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
    process_install_script()
    process_cli_tool()
