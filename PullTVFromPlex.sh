#!/bin/bash

set -e # Exit immediately if a command exits with a non-zero status.

# To-do:
#  If DEST FS supports perms, links, etc... set flags accordingly
#  Invoke sudo where appropriate (and if perm'ed)


# Object to Sync:
VOLUME=/Volumes/Media
FOLDER='TV'

# Source parameters:
SOURCE_FQDN=plexmaster.someotherrandomdomain.com
SOURCE_USER=plex
SOURCE_FLAG=${VOLUME}/.mounted
SOURCE="${SOURCE_USER}@${SOURCE_FQDN}:${VOLUME}/${FOLDER}/"

# Destination parameters:
DEST="${VOLUME}/${FOLDER}"

# rsync Flags:
unset RSYNC_FLAGS
RSYNC_FLAGS="${RSYNC_FLAGS} --archive --progress --verbose --itemize-changes "
RSYNC_FLAGS="${RSYNC_FLAGS} --no-perms --no-owner --no-group --no-times --no-links "
RSYNC_FLAGS="${RSYNC_FLAGS} --size-only --partial --append --delete-during "

# Confirm Destination
echo "Checking destination volume: ${VOLUME}..."
if [[ $OSTYPE == "darwin"* ]]; then # MacOS specific code here
    echo "   Running on MacOS"
    set -x
##  FoundFlag=$( mount | grep ^/dev | grep Volumes/Media | awk '{print $3}' )
    FoundFlag=$( mount | grep Volumes/Media | awk '{print $3}' )
elif [[ $OSTYPE == "linux"* ]]; then # Linux specific code here
    echo "   Running on Linux"
    FoundFlag=$( lsblk | grep ${VOLUME} | awk '{print $NF}' )
else
    echo "Unsupported operating system"
    exit 99
fi

if [[ $FoundFlag != ${VOLUME} ]]; then
    echo "Something has gone wrong: Does volume: ${VOLUME} exist on this machine?"
    exit 99
fi 
echo "   Volume checks out."

echo "Checking destination folder: ${DEST}..."
# It's possible that the following not get executed because 'set -e'
touch ${DEST}/@@TEST.FILE@@ 2> /dev/null
if [[ $? != 0 ]]; then
    echo "Something has gone wrong: Folder: ${DEST} doesn't appear to be writable by you."
    exit 99
fi
# Don't need to do this as rsync is expected to remove it: rm ${VOLUME}/${FOLDER}/@@TEST.FILE@@ 2> /dev/null
echo "   Destination Folder checks out."

# Confirm SOURCE reachability:
echo "Checking that the source on $SOURCE_FQDN is mounted and readable for user: $SOURCE_USER..."
if [[ ${SOURCE_FLAG} != $(ssh ${SOURCE_USER}@${SOURCE_FQDN} ls ${SOURCE_FLAG}) ]]; then
    echo "Sorry, using credentials ${SOURCE_USER} at ${SOURCE_FQDN} don't expose ${SOURCE_FLAG}"
    exit 99
fi
echo "   Source volume checks out."

# Gather statistics:
FS_BEFORE=$(df -h ${DEST} | grep ^/dev | awk '{print $4}')

# Do the deed:
echo "Syncing ${SOURCE} to ${DEST} (with options: $@)"
rsync ${RSYNC_FLAGS[@]} ${SOURCE} ${DEST} $@

# Gather statistics:
FS_AFTER=$(df -h ${DEST} | grep ^/dev | awk '{print $4}')

echo "Free Space on ${DEST} before syncing is: ${FS_BEFORE}"
echo "Free Space on ${DEST} after syncing is: ${FS_AFTER}"

exit 0
