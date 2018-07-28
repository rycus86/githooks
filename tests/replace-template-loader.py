"""
This small program replaces the inline base template
in the install script for a more sensible coverage percentage,
while keeping all lines at the same position.
"""

import re
import sys

PATTERN="(.+)(BASE_TEMPLATE_CONTENT='[^']+')(.+)"
REPLACEMENT="BASE_TEMPLATE_CONTENT=$(cat %s/base-template.sh)"

if __name__ == '__main__':
    base_folder = sys.argv[1]
    file_path = '%s/install.sh' % base_folder

    contents = ''

    with open(file_path, 'r') as source:
        contents = source.read()

    match = re.match(PATTERN, contents, flags=re.MULTILINE | re.DOTALL)
    before, template, after = match.groups()

    contents = '%s%s %s%s' % (
        before, 
        (REPLACEMENT % base_folder),
        '\n'.join(['#> %s' % line for line in template.splitlines()]),
        after
    )
    
    with open(file_path, 'w') as target:
        target.write(contents)
