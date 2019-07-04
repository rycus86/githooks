#!/bin/sh
# Download script for use with 
#`git config --global --set githooks.download.app`

#####################################################
# Parse an url into parts
#   https://stackoverflow.com/a/6174447/293195
# Returns:
#   parsed parts of the url
#####################################################
parse_url(){
    # extract the protocol
    PARSED_PROTOCOL="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
    # remove the protocol
    PARSED_URL="$(echo ${1/$PARSED_PROTOCOL/})"
    # extract the user (if any)
    PARSED_USER="$(echo $PARSED_URL | grep @ | cut -d@ -f1)"
    # extract the host and PARSED_PORT
    local hostport
    hostport="$(echo ${PARSED_URL/$PARSED_USER@/} | cut -d/ -f1)"
    # by request host without port    
    PARSED_HOST="$(echo $hostport | sed -e 's,:.*,,g')"
    # by request - try to extract the port
    PARSED_PORT="$(echo $hostport | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
    # extract the path (if any)
    PARSED_PATH="$(echo $PARSED_URL | grep / | cut -d/ -f2-)"
}

# Input
DOWNLOAD_FILENAME="$1"
OUTPUT_FILE="$2"
MAIN_DOWNLOAD_URL="https://raw.githubusercontent.com/rycus86/githooks/master"

# Download with credentials over `git credential fill`
parse_url "$FILE"
PARSED_PROTOCOL=$(echo "$PARSED_PROTOCOL" | sed -e 's@://@@')
CREDENTIALS=$(echo -e "protocol=$PARSED_PROTOCOL\nhost=$PARSED_HOST\n\n" | git credential fill)
if [ $? -ne 0 ]; then
    echo "! Getting download credential failed."
    return 1
fi
USER=$(echo "$CREDENTIALS" | grep -Eo0 "username=.*$" | cut -d "=" -f2-)
PASSWORD=$(echo "$CREDENTIALS" | grep -Eo0 "password=.*$" | cut -d "=" -f2-)

DOWNLOAD_URL="$MAIN_DOWNLOAD_URL/$DOWNLOAD_FILENAME"
echo "  Downlad $DOWNLOAD_URL ..."

if curl --version >/dev/null 2>&1; then
    curl -fsSL -o "$OUTPUT_FILE" -u "$USER:$PASSWORD" "$DOWNLOAD_URL" 2>/dev/null
elif wget --version >/dev/null 2>&1; then
    wget -O "$OUTPUT_FILE" -user="$USER" --password="$PASSWORD" "$DOWNLOAD_URL" 2>/dev/null
else
    echo "! Cannot download file '$DOWNLOAD_URL' - needs either curl or wget"
    return 1 
fi

# Check that its not a HTML file, then something is wrong!
# We cannot really detect when it failed, curl returns anything 
# (login page, status code is not reliable?)
# We use '<''html' to not match the install.sh
if ( cat "$OUTPUT_FILE" | grep -q '<''html' ) ; then
    echo "! Cannot download file '$1' - wrong format!"
    return 1
fi