#!/usr/bin/env bash
# 
# MirrorMediaToSpare.sh
# Version 0.0.1 Initial Release
#
# shellcheck disable=SC2329  # Ignore Unused functions left in for readability
# shellcheck disable=SC2034  # Ignore Unused variables left in for readability
# shellcheck disable=SC2317  # Ignore unreachable functions left in for readability
#
# Rubric: 
# The flow goes like this:
# 1) Look for a mounted volume called "${_Source_Mount_Point}"
#     - If not mounted, throw a message and gracefully exit
#     otherwise:
#     - Store its device ID for later use
#
# 2) Sift thru the output of `blkid` to see if there's a device with a label of '${_Target_Device_Label}'
#     - If there is, and it's mounted somewhere, proceed. 
#     otherwise:
#     - Throw a message and gracefully exit
#
# 3) If there's an executable called "system_snapshot" in the path, run it.
#
# 4) Based on the commandline options, set up the rsync command string and execute it.
#
# 5) Print some nice stats, throw a message and gracefully exit
#
# 
# To-Do:
#   - "Zap" the logfile? That's a problem...
#   - printf --> fn_msg_...
#   - CLI option to skip system_snapshot?
#
#
############################# fn_msg_ functions ##########################################
function fn_msg_Debug() { # Prints a provided 'debug' message. Try to keep it under ~70 characters
	[[ -n ${_INTERACTIVE} && -n "${_DEBUG}" ]] && printf "\r\e[2K   [\e[93m*\e[0m] "
	[[ -n "${_DEBUG}" ]] && printf "%s\n" "$@"
} # fn_msg_Info

function fn_msg_Info() { # Prints a provided 'info' message. Try to keep it under ~70 characters
	[[ -n ${_INTERACTIVE} ]] && printf "\r\e[2K   [\e[93mi\e[0m] "
	printf "%s\n" "$@"
} # fn_msg_Info

function fn_msg_Status() { # Prints a provided 'status' message. Try to keep it under ~70 characters
  [[ -n ${_INTERACTIVE} ]] && printf "\r\e[2K        "
	printf "%s\n" "$@"
} # fn_msg_Status

function fn_msg_Success() { # Prints a provided 'success' message. Try to keep it under ~70 characters
	[[ -n ${_INTERACTIVE} ]] && { sleep 1; printf "\r\e[2K   [✅] "; }
	printf "%s\n" "$@"
} # fn_msg_Success

function fn_msg_Failure() { # Prints a provided 'failure' message. Try to keep it under ~70 characters
  printf "\r\e[2K   [\e[91m\xe2\x9d\x8c\e[0m] "
	printf "%s\n" "$@"
} # fn_msg_Failure

function fn_msg_Multiline() { # Prints a provided 'multi-line string' with correct left (tab) indent(s)
	echo "$@" | while IFS= read -r line; do printf "\t%s\n " "$line" ; done
# The `sed` way doesn't deal well with the first line indentation
#  echo "     $@" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\n        /g'
} # fn_msg_Multiline

############################# End of fn_msg_ functions ######################################

function Initialize() {
  # Identify myself
  _scriptname=$(basename -s .sh "$0")

  # Set up logging
  _logfile="/tmp/${_scriptname}.log"          # -->> Erase the logfile first?  cp /dev/null ${_logfile}
  exec > >(tee -a "$_logfile") 2>&1

  # Set up forensic variables
  unset _DEBUG
  if [[ -n $optDebug ]]; then
    _DEBUG="TRUE"
    fn_msg_Debug " * * * Debug mode is enabled."
  fi
  unset _INTERACTIVE ; [[ -t 0 ]] && _INTERACTIVE=TRUE
  UpArrow=$'\e'[A ; [[ -n "${_DEBUG}" || -z ${_INTERACTIVE} ]] && UpArrow=''

  fn_msg_Info "Initializing $(basename "$0")..." 

  # Exit Codes:
  ExitCodeOK=0
  ExitCodeDependencyFailure=99
  ExitCodeDebug=98
  ExitCodeDryRun=97
  ExitCodeDestBlkid=96
  ExitCodeSourceMount=95
  ExitCodeDestMount=94

  # App-specific Variables & Constants:
  _Source_Mount_Point="/Volumes/Media" # N.B.: This may cause issues as the 'source' of an rsync.
  _tmp_Destination="NULL"
  _Target_Device_Label="8TB-Media"

} # End of function Initialize

function ParseParameters() { # Assumes you are passing this function '$@' from the command line
  unset optDebug
  unset optDryRun
  unset optNoDelete
  unset optQuiet
  unset optShowExitCodes
  unset optZapLogFile
  unset optVerbose

  while [ -n "$1" ]; do
    case $1 in
      -d | --debug )
        optDebug=TRUE
        ;;
      --dry-run | --dryrun )
        optDryRun=TRUE
        ;;
      -n | --no-delete | --no-del* )    # Need to test this wildcard'ing
        optNoDelete=TRUE
        ;;
      -q | --quiet )
        optQuiet=TRUE
        ;;
      -s | --show* )
        optShowExitCodes=TRUE
        ;;
      -z | --zap )
        optZapLogFile=TRUE
        ;;
      -v | --verbose )
        optVerbose=TRUE
        ;;
      * )
        printf "  %s\n" "Command line options:"
        printf "\t%s\n" "-h | --help         <--- Show Command line options."
        printf "\t%s\n" "-d | --debug        <--- Force DEBUG mode ON."
        printf "\t%s\n" "-n | --no-delete    <--- do not delete files on the destination."
        printf "\t%s\n" "-q | --quiet        <--- Squelch rsync output."
        printf "\t%s\n" "-s | --show         <--- Show (possible) exit codes for this app."
        printf "\t%s\n" "-v | --verbose      <--- Set verbose output."
        printf "\t%s\n" "-z | --zap          <--- Zap existing log file."
        printf "\t%s\n" "--dry-run           <--- Don't actually perform copying."
        exit $ExitCodeOK
        ;;
    esac
    shift
  done
  if [[ $optVerbose == TRUE ]]; then
    echo Report option Flags here because... Verbose
  fi
} # End of function ParseParameters()

function Main() {

  # Verify that $_Source_Mount_Point is, in fact, mounted.
  fn_msg_Info "Checking to see that ${_Source_Mount_Point} is mounted."
  _Source_Device=$( mount | grep ${_Source_Mount_Point} | awk '{print $1}' )
  if [[ -n "${_Source_Device}" ]]; then
    printf $UpArrow
    if [[ -z $optVerbose ]]; then
      fn_msg_Success "${_Source_Mount_Point} is mounted"
    else
      fn_msg_Success "${_Source_Mount_Point} is mounted at ${_Source_Device}"
    fi
  else
    fn_msg_Failure "${_Source_Mount_Point} is not mounted. Continuing is not possible."
    exit $ExitCodeSourceMount
  fi

  # Find the device id of the Target device:
  fn_msg_Info "Checking Block IDs to see that Target Device ${_Target_Device_Label} exists."
  _Target_Device=$(blkid | grep "${_Target_Device_Label}" | awk -F ':' '{print $1}')
  if [[ -n ${_Target_Device} ]]; then
    printf $UpArrow
    if [[ -z $optVerbose ]]; then
      fn_msg_Success "${_Target_Device_Label} exists."
    else
      fn_msg_Success "${_Target_Device_Label} exists at ${_Target_Device}"
    fi
  else
    fn_msg_Failure "${_Target_Device_Label} was not found. Continuing is not possible."
    [[ -n optDebug ]] && blkid
    exit $ExitCodeDestMount
  fi

  # Find the mount point of the Target:
  fn_msg_Info "Confirming that ${_Target_Device_Label} is mounted."
  _Target_Mount_Point=$(mount | grep "$_Target_Device" | tail -1 | awk -F ' ' '{print $3}')
  if [[ -z ${_Target_Mount_Point} ]]; then
    fn_msg_Failure "A device with label ${_Target_Device_Label} is attached at ${_Target_Device} but is not mounted." 
    exit $ExitCodeDestMount
  else
    printf $UpArrow 
    if [[ -z $optVerbose ]]; then
      fn_msg_Success "${_Target_Device_Label} is mounted."
    else
      fn_msg_Success "${_Target_Device_Label} is mounted at ${_Target_Mount_Point}."
    fi
  fi

  fn_msg_Info "Environment Summary:"
  fn_msg_Status "_Source_Mount_Point is ${_Source_Mount_Point}"
  fn_msg_Status "_Target_Device_Label is ${_Target_Device_Label}"
  fn_msg_Status "_Target_Device is ${_Target_Device}"
  fn_msg_Status "_Target_Mount_Point is ${_Target_Mount_Point}"
  fn_msg_Status ""
  fn_msg_Info "Starting to mirror ${_Source_Mount_Point} to ${_Target_Mount_Point}"

  _df_BEFORE=$(df -h ${_Source_Mount_Point} ${_Target_Mount_Point})
  fn_msg_Status ""
  fn_msg_Info "DiskFree (before):"
  fn_msg_Multiline "${_df_BEFORE}"

  if [[ "$optDryRun" != "TRUE" ]]; then
    _snapshot=$(which system_snapshot)
    if [[ -n "$_snapshot" ]]; then
      fn_msg_Info "Running system_snapshot."  
      system_snapshot 
    else
      fn_msg_Info "* * * Warning: system_snapshot not found on this system (Skipping)."
    fi
  else
    fn_msg_Info "Dry Run option selected; skipping system_snapshot"
  fi

  _Rsync_Flags=" --archive --partial --append --verbose "

  if [[ "${optQuiet}" == "TRUE" ]]; then
    _Rsync_Flags=${_Rsync_Flags/--verbose/} # ${OriginalString/Pattern/NewPattern}
  fi

  if [[ "${optDryRun}" == "TRUE" ]]; then
    _Rsync_Flags+=" --dry-run " 
  fi

  if [[ "${optNoDelete}" != "TRUE" ]]; then
    _Rsync_Flags+=" --delete-after " 
  fi

  if [[ "${optVerbose}" == "TRUE" ]]; then
    _Rsync_Flags+=" --itemize-changes --progress " 
  fi

  fn_msg_Info "$(printf "Doing: rsync ${_Rsync_Flags} ${_Source_Mount_Point}/ ${_Target_Mount_Point}")"

  [[ -n "${_DEBUG}" ]] && exit $ExitCodeOK

  rsync ${_Rsync_Flags} ${_Source_Mount_Point}/ ${_Target_Mount_Point}

  fn_msg_Info "DiskFree (before):"
  fn_msg_Multiline "${_df_BEFORE}"
  
  fn_msg_Info "DiskFree (after):"
  fn_msg_Multiline "$( df -h ${_Source_Mount_Point} ${_Target_Mount_Point} )"
  
} # End of function Main()


# Let us begin...
START=$SECONDS

ParseParameters "$@"                       # Start by getting the Command Line Parameters

Initialize

Main

fn_msg_Success "That took $(date -d @$(( SECONDS - START )) +"%M:%S")."

exit $ExitCodeOK

_DEBUG="TRUE"
fn_msg_Debug "This is fn_msg_Debug"
fn_msg_Status "This is fn_msg_Status"
fn_msg_Success "This is fn_msg_Success"
fn_msg_Failure "This is fn_msg_Failure"
fn_msg_Info "This is fn_msg_Info"

fn_msg_Status ""
fn_msg_Info "Output from ls:"
fn_msg_Multiline "$( ls -alh ./[Mm]* )"

fn_msg_Status ""
fn_msg_Info "Output from blkid:"
fn_msg_Multiline "$( blkid )"
