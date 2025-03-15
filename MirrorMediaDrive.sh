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
#
# 3) 
#
# 4) 
#
# 5) 
#
# 

function Main() {
_scriptname=$(basename -s .sh "$0")

_logfile="/tmp/${_scriptname}.log"          # -->> Erase the logfile first?  cp /dev/null ${_logfile}
exec > >(tee -a "$_logfile") 2>&1

printf "%s is starting; validating environment...\n" $(basename "$0")

_Source_Mount_Point="/Volumes/Media/" 
_destination="NULL"

_Target_Device_Label="8TB-Media"
# Find the location of the Target device:
_Target_Device=$(blkid | grep "${_Target_Device_Label}" | awk -F ':' '{print $1}')
if [[ -z $_Target_Device ]]; then
  printf "Error:\n"
  blkid
  printf " * * *    No BlockID was found for %s.\n\n" "$_Target_Device_Label"
  exit 0
else
  _Target_Mount_Point=$(mount | grep "$_Target_Device" | tail -1 | awk -F ' ' '{print $3}')
  if [[ -z $_Target_Mount_Point ]]; then
    printf "Error:\n"
    printf " * * *   A device with label %s is attached at %s but is not mounted.\n\n" "$_Target_Device_Label" "$_Target_Device"
    exit 0
  else
    _destination="${_Target_Mount_Point}"
  fi
fi

echo _Target_Device_Label is "$_Target_Device_Label"
echo _Target_Device is "$_Target_Device"
echo _Target_Mount_Point is "$_Target_Mount_Point"

if [[ "$_destination" == "NULL" ]]; then
  exit 0
else
  printf "\nStarting rsync of %s to %s.\n" "$_Source_Mount_Point" "$_destination" 
fi

# exit 0

_df_BEFORE=$(df -h "$_Source_Mount_Point" "$_destination")
printf "\n\nDiskFree (before):\n %s\n\n\n" "$_df_BEFORE"

_snapshot=$(which system_snapshot)
if [[ -n "$_snapshot" ]]; then
  printf "Running system_snapshot\n."  
  system_snapshot 
else
  printf "* * * Warning: system_snapshot not found on this system (Skipping).\n"
fi

rsync --archive --partial --append --itemize-changes "$_Source_Mount_Point" "$_destination" --delete 

printf "\n\nDiskFree (before):\n %s\n" "$_df_BEFORE"
printf "\n\nDiskFree (after):\n" 
df -h "$_Source_Mount_Point" "$_destination"
}

function Initialize() {
  fn_msg_Status "Initializing..."

  unset _DEBUG     #  ;  _DEBUG=TRUE
  if [[ -n $optDebug ]]; then
    _DEBUG="TRUE"
  fi

  unset _INTERACTIVE ; [[ -t 0 ]] && _INTERACTIVE=TRUE
  UpArrow=$'\e'[A ; [[ -n "${_DEBUG}" || -z ${_INTERACTIVE} ]] && UpArrow=''

  # _DEBUG="TRUE"  # This is just while testing!

  fn_msg_Debug " * * * Debug mode is enabled."

}

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

# Let us begin...
START=$SECONDS

Main
fn_msg_Success "That took $(date -jr $(( $SECONDS - $START ))  +"%M:%S") seconds."

exit $ExitCodeOK

