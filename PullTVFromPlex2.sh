#!/bin/bash

# set -e # Exit immediately if a command exits with a non-zero status.

# To-do:
#  If DEST FS supports perms, links, etc... set flags accordingly
#  Invoke sudo where appropriate (and if perm'ed)
#  Enforce single-instance execution, e.g.:
#       if [ -f "/tmp/PullTVFromPlex2.lock" ]; then
#           echo "Another instance of this script is already running."
#           exit 1
#       fi
#       touch "/tmp/PullTVFromPlex2.lock"
#       trap 'rm -f "/tmp/PullTVFromPlex2.lock"; exit 1' INT TERM
#  See also: myscript_with_lock.sh in Public repo

echo "Starting TV sync from Plexmaster... at time: $(date)"

DEBUG=1

unset DEBUG

[ -n "${DEBUG}" ] && set -x || set +x

# Object to Sync:
VOLUME='/Volumes/Media'
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
RSYNC_FLAGS="${RSYNC_FLAGS} --archive --verbose --itemize-changes "
RSYNC_FLAGS="${RSYNC_FLAGS} --no-perms --no-owner --no-group --no-times --no-links "
RSYNC_FLAGS="${RSYNC_FLAGS} --size-only --partial --append --delete-during "
# RSYNC_FLAGS="${RSYNC_FLAGS} --progress "

[ -n "${DEBUG}" ] && echo "RSYNC_FLAGS: ${RSYNC_FLAGS}"

# Confirm Destination
#  NB: This fails on Debian, since 'mount' is in /usr/bin/mount.
#      Consider something like:
#      mountCmd=$(which mount)
#      $mountCmd blah-blah-blah 
echo "Checking destination volume: ${VOLUME}..."
if [[ $(/sbin/mount | grep -c "${VOLUME}") != 1 ]]; then
    echo "Something has gone wrong: Does volume: ${VOLUME} exist on this machine?"
    /sbin/mount
    exit 99
else
    echo "   Volume checks out."
fi

echo "Checking destination folder: ${DEST}..."
# It's possible that the following not get executed if 'set -e'
touch ${DEST}/@@TEST.FILE@@ 2> /dev/null
if [[ $? != 0 ]]; then
    echo "Something has gone wrong: Folder: ${DEST} doesn't appear to be writable by you."
    exit 99
else
    echo "   Destination Folder checks out."
fi

# Confirm SOURCE reachability:
echo "Checking that the source on $SOURCE_FQDN is mounted and readable for user: $SOURCE_USER..."
if [[ ${SOURCE_FLAG} != $(ssh ${SOURCE_USER}@${SOURCE_FQDN} ls ${SOURCE_FLAG}) ]]; then
    echo "Sorry, using credentials ${SOURCE_USER} at ${SOURCE_FQDN} don't expose ${SOURCE_FLAG}"
    exit 99
else
    echo "   Source volume checks out."
fi

# Gather statistics:
FS_BEFORE=$(df -h ${DEST} | grep ^/dev | awk '{print $4}')

# Do the deed:
echo "Syncing ${SOURCE} to ${DEST} (with options: $@)"
/usr/local/bin/rsync ${RSYNC_FLAGS[@]} ${SOURCE} ${DEST} $@

# Gather statistics:
FS_AFTER=$(df -h ${DEST} | grep ^/dev | awk '{print $4}')

echo "Free Space on ${DEST} before syncing is: ${FS_BEFORE}"
echo "Free Space on ${DEST} after syncing is: ${FS_AFTER}"

exit 0
