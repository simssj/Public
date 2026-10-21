#!/bin/bash
#
# FileName: PullTVFromPlex.v3.sh
#
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

############################# fn_msg_ functions ##########################################
  function fn_msg_Debug() { # Prints a provided 'debug' message. Try to keep it under ~70 characters
    [[ -n ${_INTERACTIVE} && -n "${_DEBUG}" ]] && printf "\r\e[2K   [\e[93m*\e[0m] "
    [[ -n "${_DEBUG}" ]] && printf "%s\n" "$@"
  } # fn_msg_Info

  function fn_msg_Info() { # Prints a provided 'info' message. Try to keep it under ~70 characters
    [[ -n ${_INTERACTIVE} ]] && printf "\r\e[2K   [\e[93mi\e[0m] "
    printf "%s\n" "$@"
  } # fn_msg_Info

  function fn_msg_Failure() { # Prints a provided 'failure' message. Try to keep it under ~70 characters
    printf "\r\e[2K   [\e[91m\xe2\x9d\x8c\e[0m] "
    printf "%s\n" "$@"
  } # fn_msg_Failure

  function fn_msg_Multiline() { # Prints a provided 'multi-line string' with correct left (tab) indent(s)
    echo "$@" | while IFS= read -r line; do printf "\t%s\n " "$line" ; done
  } # fn_msg_Multiline

  function fn_msg_Status() { # Prints a provided 'status' message. Try to keep it under ~70 characters
    [[ -n ${_INTERACTIVE} ]] && printf "\r\e[2K       "
    printf "%s\n" "$@"
  } # fn_msg_Status

  function fn_msg_Success() { # Prints a provided 'success' message. Try to keep it under ~70 characters
    [[ -n ${_INTERACTIVE} ]] && { sleep 1; printf "\r\e[2K   ✅ "; }
    printf "%s\n" "$@"
  } # fn_msg_Success
############################# End of fn_msg_ functions ######################################

function ParseCommandLineParams() { # Assumes you are passing this function '$@' from the command line
  unset optDebug
  unset optVerbose
  unset optDryRun

  while [ -n "$1" ]; do
    case $1 in
      -d | --debug )
        optDebug=TRUE
        ;;
      -v | --verbose | -p | --progress )
        optVerbose=TRUE
        ;;
      --dry-run | --dryrun )
        optDryRun=TRUE
        ;;
      * )
        printf "  %s\n" "Command line options:"
        printf "\t%s\n" "-d | --debug        <--- Force DEBUG mode ON."
        printf "\t%s\n" "-v | --verbose      <--- Show file transfer progress."
        printf "\t%s\n" "--dry-run           <--- Analyze and report, but don't sync."
        exit $ExitCodeOK
        ;;
    esac
    shift
  done
} # End of function ParseCommandLineParams()

function ShowParams() { # Shows whatever Command-Line options have been detected and set:
  if [[  -n "${optDebug}${optVerbose}${optDryRun}" || -n "${_DEBUG}" ]]; then
    fn_msg_Info "Parameters passed on the command line were:"
    if [[ -n ${optDebug} ]]; then
      fn_msg_Status "optDebug: $optDebug"
      if [[ -n ${_INTERACTIVE} ]]; then
        fn_msg_Status "Session is Interactive."
      fi
    fi

    if [[ -n ${optVerbose} ]]; then
      fn_msg_Status "optVerbose: $optVerbose"
    fi

    if [[ -n ${optDryRun} ]]; then
      fn_msg_Status "optDryRun: $optDryRun"
    fi
  fi
} # End of function ShowParams() 

function Initialize() {
  START=$SECONDS

# Exit Codes:
  ExitCodeOK=0
  ExitCodeDependencyFailure=1
  ExitCodeUnsupported=2
  ExitCodeNoLocalVolume=3
  ExitCodeNoLocalAccess=4
  ExitCodeNoRemoteAccess=4

  ParseCommandLineParams $@
  
  unset _DEBUG     #  ;  _DEBUG=TRUE
  if [[ -n ${optDebug} ]]; then
    _DEBUG="TRUE"
    fn_msg_Debug " * * * Debug mode is enabled."
  fi

  unset _INTERACTIVE ; [[ -t 0 ]] && _INTERACTIVE=TRUE
  UpArrow=$'\e'[A ; [[ -n "${_DEBUG}" || -z ${_INTERACTIVE} ]] && UpArrow=''

  ShowParams

  OSCheck

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
  if [[ -n ${optVerbose} ]]; then
    RSYNC_FLAGS="${RSYNC_FLAGS} --progress "
  fi
  RSYNC_FLAGS="${RSYNC_FLAGS} --archive --verbose --itemize-changes "
  RSYNC_FLAGS="${RSYNC_FLAGS} --size-only --partial --append --delete-during "
  RSYNC_FLAGS="${RSYNC_FLAGS} --no-perms --no-owner --no-group --no-times --no-links "

  [ -n "${_DEBUG}" ] && fn_msg_Debug "RSYNC_FLAGS: ${RSYNC_FLAGS}"
} # End of function Initialize()

function OSCheck() {
  case "$OSTYPE" in
      linux*)
          fn_msg_Debug "Operating System 'linux' detected."
          MOUNT='/usr/bin/mount'
          RSYNC='/usr/bin/rsync'
          ;;
      darwin*)
          fn_msg_Debug "Operating System 'MacOS' detected."
          MOUNT='/sbin/mount'
          RSYNC='/usr/local/bin/rsync'
          ;;
      *)
          fn_msg_Failure "Unsupported Operating System detected. Cannot continue."
          exit ExitCodeUnsupported
          ;;
  esac  
 [[ ! -x $MOUNT ]] && { fn_msg_Failure "The 'mount' command: '$MOUNT' is not executable. Continuing is not possible." ; exit "$ExitCodeDependencyFailure" ; }
 [[ ! -x $RSYNC ]] && { fn_msg_Failure "The 'rsync' command: '$RSYNC' is not executable. Continuing is not possible." ; exit "$ExitCodeDependencyFailure" ; }
} # End of function OSCheck() 

function Main() {
  fn_msg_Status "Starting TV sync from Plexmaster on $(date)."
  CommandLineParams=$@
  Initialize "${CommandLineParams}"

  if [[ $($MOUNT | grep -c "${VOLUME}") -ne 1 ]]; then
    fn_msg_Failure "Something has gone wrong: Does volume: ${VOLUME} exist on this machine?"
    # exit $ExitCodeNoLocalVolume
  else
    fn_msg_Success "Local Volume: '$VOLUME' checks out."
  fi 

  fn_msg_Status "Checking destination folder: ${DEST}..."
  touch ${DEST}/@@TEST.FILE@@ 2> /dev/null
  if [[ $? != 0 ]]; then
      fn_msg_Failure "Something has gone wrong: Folder: ${DEST} doesn't appear to be writable by you."
      exit $ExitCodeNoLocalAccess
  else
      fn_msg_Success "Destination Folder is writable."
  fi

  # Confirm SOURCE reachability:
  fn_msg_Status "Checking that the source on $SOURCE_FQDN is mounted and readable for user: $SOURCE_USER..."
  if [[ ${SOURCE_FLAG} != $(ssh ${SOURCE_USER}@${SOURCE_FQDN} ls ${SOURCE_FLAG}) ]]; then
      fn_msg_Failure "Sorry, using credentials ${SOURCE_USER} at ${SOURCE_FQDN} don't expose ${SOURCE_FLAG}"
      exit $ExitCodeNoRemoteAccess
  else
    fn_msg_Success "Source volume checks out."
  fi

  # Gather statistics:
  FS_BEFORE=$(df -h ${DEST} | grep ^/dev | awk '{print $4}')

  # Do the deed:
  fn_msg_Status "Syncing ${SOURCE} to ${DEST} (with options: $@)" # Make this conditional on if options are specified.
  $RSYNC ${RSYNC_FLAGS[@]} ${SOURCE} ${DEST} $@ --dry-run

  # Gather statistics:
  FS_AFTER=$(df -h ${DEST} | grep ^/dev | awk '{print $4}')

  fn_msg_Info "Free Space on ${DEST} before syncing is: ${FS_BEFORE}"
  fn_msg_Info "Free Space on ${DEST} after syncing is: ${FS_AFTER}"

  ET=$(( SECONDS - START ))
  fn_msg_Success "Finished at $(date) [$(printf '%02d:%02d:%02d\n' $((ET/3600)) $((ET%3600/60)) $((ET%60)))]."
} # End of function Main()

Main "$@"
exit $ExitCodeOK 

function fs_type() {
    findmnt -no FSTYPE -T "$1" 2>/dev/null || stat -f -c %T "$1"
}

fs_type /home

if [[ "$fstype"* = "ext4" ]]; then
  printf "ext4"
fi
