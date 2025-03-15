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
# 4) Run the rsync.
#
# 5) Print some nice stats, throw a message and gracefully exit
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
  [[ -n ${_INTERACTIVE} ]] && printf "\r\e[2K       "
	printf "%s\n" "$@"
} # fn_msg_Status

function fn_msg_Success() { # Prints a provided 'success' message. Try to keep it under ~70 characters
	[[ -n ${_INTERACTIVE} ]] && { sleep 1; printf "\r\e[2K   ✅ "; }
	printf "%s\n" "$@"
} # fn_msg_Success

function fn_msg_Failure() { # Prints a provided 'failure' message. Try to keep it under ~70 characters
  printf "\r\e[2K   [\e[91m\xe2\x9d\x8c\e[0m] "
	printf "%s\n" "$@"
} # fn_msg_Failure
############################# End of fn_msg_ functions ######################################

function Initialize() {
  _scriptname=$(basename -s .sh "$0")

  _logfile="/tmp/${_scriptname}.log"          # -->> Erase the logfile first?  cp /dev/null ${_logfile}
  exec > >(tee -a "$_logfile") 2>&1

  fn_msg_Status "Initializing $(basename "$0")..." 

  unset _DEBUG     #  ;  _DEBUG=TRUE
  if [[ -n $optDebug ]]; then
    _DEBUG="TRUE"
    fn_msg_Debug " * * * Debug mode is enabled."
  fi

  unset _INTERACTIVE ; [[ -t 0 ]] && _INTERACTIVE=TRUE
  UpArrow=$'\e'[A ; [[ -n "${_DEBUG}" || -z ${_INTERACTIVE} ]] && UpArrow=''

# Exit Codes:
  ExitCodeOK=0
  ExitCodeDependencyFailure=99
  ExitCodeDebug=98
  ExitCodeDryRun=97
  ExitCodeDestBlkid=96
  ExitCodeDestMount=96

# App-specific Variables & Constants:
  _Source_Mount_Point="/Volumes/Media" # N.B.: This may cause issues as the 'source' of an rsync.
  _tmp_Destination="NULL"
  _Target_Device_Label="8TB-Media"

} # End of function Initialize

function ParseParams() { # Assumes you are passing this function '$@' from the command line
  unset optDebug
  unset optDryRun
  unset optNoDelete
  unset optShowExitCodes
  unset optZapLogFile
  unset optVerbose

  while [ -n "$1" ]; do
    case $1 in
      -d | --debug )
        optDebug=TRUE
        ;;
      -n | --no-delete | --no-del* )
        optNoDelete=TRUE
        ;;
      -s | --show* )
        optShowExitCodes=TRUE
        ;;
      -v | --verbose )
        optVerbose=TRUE
        ;;
      -z | --zap )
        optZapLogFile=TRUE
        ;;
      --dry-run | --dryrun )
        optDryRun=TRUE
        ;;
      * )
        printf "  %s\n" "Command line options:"
        printf "\t%s\n" "-h | --help         <--- Show Command line options."
        printf "\t%s\n" "-d | --debug        <--- Force DEBUG mode ON."
        printf "\t%s\n" "-n | --no-delete    <--- do not delete files on the destination."
        printf "\t%s\n" "-s | --show         <--- Show (possible) exit codes for this app."
        printf "\t%s\n" "-v | --verbose      <--- Set verbose output."
        printf "\t%s\n" "-z | --zap          <--- Zap existing log file."
        printf "\t%s\n" "--dry-run           <--- Don't actually perform copying."
        exit $ExitCodeOK
        ;;
    esac
    shift
  done
} # End of function ParseParams()

function Main() {

# Verify that $_Source_Mount_Point is, in fact, mounted.
  _tmpValue=$( mount | grep "$_Source_Mount_Point" )

  # Find the location of the Target device:
  _Target_Device=$(blkid | grep "${_Target_Device_Label}" | awk -F ':' '{print $1}')
  if [[ -z $_Target_Device ]]; then
    printf "Error:\n"
    blkid
    printf " * * *    No BlockID was found for %s.\n\n" "$_Target_Device_Label"
    exit "${ExitCodeDestBlkid}"
  else
    _Target_Mount_Point=$(mount | grep "$_Target_Device" | tail -1 | awk -F ' ' '{print $3}')
    if [[ -z $_Target_Mount_Point ]]; then
      printf "Error:\n"
      printf " * * *   A device with label %s is attached at %s but is not mounted.\n\n" "$_Target_Device_Label" "$_Target_Device"
      exit "${ExitCodeDestMount}"
    else
      _tmp_Destination="${_Target_Mount_Point}"
    fi
  fi

fn_msg_Status "_Target_Device_Label is ${_Target_Device_Label}"
fn_msg_Status "_Target_Device is ${_Target_Device}"
fn_msg_Status "_Target_Mount_Point is ${_Target_Mount_Point}"

if [[ "$_tmp_Destination" == "NULL" ]]; then
  exit "${ExitCodeDestMount}"
else
  printf "\nStarting mirror of %s to %s.\n" "$_Source_Mount_Point" "$_Target_Mount_Point" 
fi

# exit "${ExitCodeDebug}"

_df_BEFORE=$(df -h "$_Source_Mount_Point" "$_Target_Mount_Point")
printf "\n\nDiskFree (before):\n %s\n\n\n" "$_df_BEFORE"

if [[ "$optDryRun" != "TRUE" ]]; then
  _snapshot=$(which system_snapshot)
  if [[ -n "$_snapshot" ]]; then
    fn_msg_Info "Running system_snapshot."  
    system_snapshot 
  else
    fn_msg_Info "* * * Warning: system_snapshot not found on this system (Skipping)."
  fi
fi
_Rsync_Flags="--archive --partial --append --itemize-changes"

if [[ "${optDryRun}" == "TRUE" ]]; then
  _Rsync_Flags="${_Rsync_Flags} --dry-run" 
fi

if [[ "${optNoDelete}" != "TRUE" ]]; then
  _Rsync_Flags="${_Rsync_Flags} --delete" 
fi

if [[ "${optVerbose}" == "TRUE" ]]; then
  _Rsync_Flags="${_Rsync_Flags} --verbose --progress" 
fi

echo rsync "${_Rsync_Flags}" \""${_Source_Mount_Point}/"\" \""$_Target_Mount_Point"\"

printf "\n\nDiskFree (before):\n %s\n" "$_df_BEFORE"
printf "\n\nDiskFree (after):\n" 
df -h "$_Source_Mount_Point" "$_Target_Mount_Point"
} # End of function Main()


# Let us begin...
START=$SECONDS

ParseParams $@                       # Start by getting the Command Line Parameters

Initialize

# echo "Work in Progress -- Come Back Later!"
# exit $ExitCodeDebug

Main

fn_msg_Success "That took $(date -jr $(( $SECONDS - $START ))  +"%M:%S") seconds."

exit $ExitCodeOK

optDebug="TRUE"  # This is just while testing!
optDryRun=TRUE
optNoDelete=TRUE

