#!/usr/bin/env bash
# 
# MirrorMediaToSpare.sh
# Version 0.0.1 Initial Release
# Version 0.1.1 Substituted rpi-clone for system_snapshot
# Version 1.0.0rc1 Reflowed the Tourist Information
# Version 1.1 Added before/after file counts to tourist information
#
# shellcheck disable=SC2329  # Ignore Unused functions left in for readability
# shellcheck disable=SC2034  # Ignore Unused variables left in for readability
# shellcheck disable=SC2317  # Ignore unreachable functions left in for readability
#
# Rubric: 
# The flow goes like this:
# 1) First, if there's an SD Card in mmcblk0 then do an rpi-clone to back up the OS
#
# 2) Second: Mirror /Volumes/Media to /Volumes/Spare
#    a) Look for a mounted volume called "${_Source_Mount_Point}"
#       - If not mounted, throw a message and gracefully exit
#       otherwise:
#       - Store its device ID for later use
#
#    b) Sift thru the output of `blkid` to see if there's a device with a label of '${_Target_Device_Label}'
#      - If there is, and it's mounted somewhere, proceed. 
#       otherwise:
#       - Throw a message and gracefully exit
#
#    c) Based on the commandline options, set up the rsync command string and execute it.
#
#    d) Print some nice stats, throw a message and gracefully exit
#
# 
# To-Do:
#   - Examine target drive's filesystem to see it we need to do something about the flags (perms, groups, times, etc.)
#   - Might think about if partitions on mmcblk0 are mounted when we get here, and they get unmounted by rpi-clone, re-mount them when we're done.
#   - Borrow the code from "system_snapshot" to make a shadow of the mounted filesystem on / onto the target drive. (rpi-clone may not be enough)
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

function Initialize() { # Assumes that ParseParameters has already been called
  
  _scriptname=$(basename -s .sh "$0") # Identify myself

  # Set up logging
  _logfile="/tmp/${_scriptname}.log" 
  exec > >(tee -a "$_logfile") 2>&1

# Clear out the log file was requested.
  if [[ $optZapLogFile == "TRUE" ]]; then
    cp /dev/null "${_logfile}"
  fi

  # Set up forensic variables
  unset _DEBUG ; [[ -n $optDebug ]] && _DEBUG="TRUE"
  
  unset _INTERACTIVE ; [[ -t 0 ]] && _INTERACTIVE=TRUE
    UpArrow=$'\e'[A ; [[ -n "${_DEBUG}" || -z ${_INTERACTIVE} ]] && UpArrow=''

  fn_msg_Info "Initializing $(basename "$0")..." 
  fn_msg_Debug " * * * Debug mode is enabled."

  # Exit Codes:
  ExitCodeOK=0
  ExitCodeDependencyFailure=99
  ExitCodeDebug=98
  ExitCodeDryRun=97
  ExitCodeDestBlkid=96
  ExitCodeSourceMount=95
  ExitCodeDestMount=94

  # rsync specific Variables & Constants:
  _Source_Mount_Point="/Volumes/Media" # N.B.: This may cause issues as the 'source' of an rsync.
  _tmp_Destination="NULL"
  _Target_Device_Label="8TB-Media"

# rpi-clone specific Variables & Constants:
  rpi_RequiredVersion="2.0.25"
  rpi_TargetDevice="mmcblk0"
  rpi_DeviceTag="Rpi-Clone"

# Time out for a little tourist information:
  if [[ $_DEBUG == "TRUE" ]]; then
    printf "%s\n" "The following options are set:"
    printf "        %s is '%s'\n" "optDebug" "${optDebug}"
    printf "       %s is '%s'\n" "optDryRun" "${optDryRun}"
    printf "     %s is '%s'\n" "optNoDelete" "${optNoDelete}"
    printf "        %s is '%s'\n" "optQuiet" "${optQuiet}"
    printf "    %s is '%s'\n" "optShowCodes" "${optShowCodes}"
    printf "      %s is '%s'\n" "optVerbose" "${optVerbose}"
    printf "   %s is '%s'\n" "optZapLogFile" "${optZapLogFile}"
  fi

  if [[ $optShowCodes == "TRUE" ]]; then
    printf "%s\n" "Exit Codes provided by this script:"
    printf "\t%s = %s\n" "ExitCodeOK" "0"
    printf "\t%s = %s\n" "ExitCodeDependencyFailure" "99"
    printf "\t%s = %s\n" "ExitCodeDebug " "98"
    printf "\t%s = %s\n" "ExitCodeDryRun" "97"
    printf "\t%s = %s\n" "ExitCodeDestBlkid" "96"
    printf "\t%s = %s\n" "ExitCodeSourceMount" "95"
    printf "\t%s = %s\n" "ExitCodeDestMount" "94"
    exit $ExitCodeOK
  fi

} # End of function Initialize

function ParseParameters() { # Assumes you are passing this function '$@' from the command line
  unset optDebug
  unset optDryRun
  unset optNoDelete
  unset optQuiet
  unset optShowCodes
  unset optVerbose
  unset optZapLogFile

  while [ -n "$1" ]; do
    case $1 in
      -d | --debug )
        optDebug="TRUE"
        ;;
      --dry-run | --dryrun )
        optDryRun="TRUE"
        ;;
      -n | --no-del* )    # Need to test this wildcard'ing
        optNoDelete="TRUE"
        ;;
      -q | --quiet )
        optQuiet="TRUE"
        ;;
      -s | --show* )    # MOVE THIS CODE TO INITIALIZE OR SIMILAR
        optShowCodes="TRUE"
        ;;
      -v | --verbose )
        optVerbose="TRUE"
        ;;
      -z | --zap )
        optZapLogFile="TRUE"
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
} # End of function ParseParameters()

function ToCloneOrNotToClone() { 
  # This function comprises all the checks necessary to determine if mmcblk0 is suitable to receive the rpi-clone
  local _tmp
  unset _DoClone

  #  - Check if rpi-clone is installed; skip if not
  fn_msg_Info "Checking to see if rpi-clone is installed."
  if [[ -z "$(which rpi-clone)" ]]; then
    fn_msg_Failure="rpi-clone is not installed; skipping cloning."
    _DoClone=FALSE; return
  else
    printf "%s" "$UpArrow"; fn_msg_Success "rpi-clone is installed."
  fi

# Check if rpi-clone version >= 2.0.25; skip if not
  fn_msg_Info "Checking rpi-clone version."
  rpi_InstalledVersion=$(rpi-clone --version | awk '{print $NF}')
  if [[ "${rpi_InstalledVersion}" < "${rpi_RequiredVersion}" ]]; then
    fn_msg_Failure "Installed rpi-clone version is ${rpi_InstalledVersion} but version ${rpi_RequiredVersion} is required; skipping cloning."
    _DoClone=FALSE; return
  else
    printf "%s" "$UpArrow"; fn_msg_Success "rpi-clone installed version is OK."
  fi

# Check if there is a device in mmc; skip if not
  fn_msg_Info "Examining ${rpi_TargetDevice}."
  _tmp=$(lsblk | grep "${rpi_TargetDevice}")
  if [[ -z "$_tmp" ]]; then
    fn_msg_Failure "Device ${rpi_TargetDevice} does not exist; skipping cloning."  
    _DoClone=FALSE; return
  else
    if [[ $(echo "$_tmp" | wc -l) -lt "3" ]]; then
      fn_msg_Failure "Device ${rpi_TargetDevice} exists but it doesn't look like a valid target for rpi-clone; skipping cloning."  
      fn_msg_Multiline "$(lsblk | grep "${rpi_TargetDevice}")"
      _DoClone=FALSE; return
    fi
  fi

# Now check if the boot volume *IS* the mmc; skip if so
  _tmp=$(df /boot | grep ^/ | awk '{print $1}')
  if [[ "$_tmp" =~ "${rpi_TargetDevice}" ]]; then
    fn_msg_Failure "Device ${rpi_TargetDevice} appears to be the boot volume; skipping cloning."  
    fn_msg_Multiline "$(df /boot)"
    _DoClone=FALSE ; return
  fi

# Finally, check if the 2nd partition on the mmc has the label "rpi-Clone'; skip if not
  _tmp=$(blkid|grep "${rpi_TargetDevice}" | grep "${rpi_DeviceTag}" | awk '{print $1}')
  if [[ "$_tmp" =~ "${rpi_TargetDevice}" ]]; then
    printf "%s" "$UpArrow"; fn_msg_Success "${rpi_TargetDevice} contains the \"${rpi_DeviceTag}\" tag and is suitable for cloning."
    _DoClone=TRUE
  else
      fn_msg_Failure "Device ${rpi_TargetDevice} doesn't contain the tag \"${rpi_DeviceTag}\"; skipping cloning."  
    fn_msg_Multiline "$(blkid|grep "${rpi_TargetDevice}" )"
    _DoClone=FALSE
  fi

# If you get here, do this: rpi-clone -v  /dev/mmcblk0 -L rpi-Clone 
# Note: If mmcblk0 has mounted partitions, no worries because rpi-clone will dismount them automagically.
} # End of function ToCloneOrNotToClone

function Main() {
# First phase: Do the rpi-clone functions:
  if [[ "$optDryRun" == "TRUE" ]]; then
    fn_msg_Info "Dry Run option selected; skipping rpi-Clone"
  else
    ToCloneOrNotToClone
    if [[ "${_DoClone}" == "TRUE" ]]; then
      rpi_Flags=" -u "
      [[ "${optVerbose}" == "TRUE" ]] && rpi_Flags+=" -v " 
      [[ "${optQuiet}" == "TRUE" ]] && rpi_Flags+=" -q " 
      fn_msg_Info "Starting rpi-clone operation."  
      [[ "${optVerbose}" == "TRUE" ]] && fn_msg_Info "$(printf "   Doing: rpi-clone ${rpi_TargetDevice} -L ${rpi_DeviceTag} ${rpi_Flags}")"
      rpi-clone ${rpi_TargetDevice} -L ${rpi_DeviceTag} ${rpi_Flags}
    fi
  fi

# Second phase: proceed to clone /Volumes/Media to /Volumes/Spare:
  # Verify that $_Source_Mount_Point is, in fact, mounted.
  fn_msg_Info "Checking to see that ${_Source_Mount_Point} is mounted."
  _Source_Device=$( mount | grep ${_Source_Mount_Point} | awk '{print $1}' )
  if [[ -n "${_Source_Device}" ]]; then
    printf "%s" "${UpArrow}"
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
    printf "%s" "${UpArrow}"
    if [[ -z $optVerbose ]]; then
      fn_msg_Success "${_Target_Device_Label} exists."
    else
      fn_msg_Success "${_Target_Device_Label} exists at ${_Target_Device}"
    fi
  else
    fn_msg_Failure "${_Target_Device_Label} was not found. Continuing is not possible."
    [[ -n $_DEBUG ]] && blkid
    exit ${ExitCodeDestMount}
  fi

  # Find the mount point of the Target:
  fn_msg_Info "Confirming that ${_Target_Device_Label} is mounted."
  _Target_Mount_Point=$(mount | grep "$_Target_Device" | tail -1 | awk -F ' ' '{print $3}')
  if [[ -z ${_Target_Mount_Point} ]]; then
    fn_msg_Failure "A device with label ${_Target_Device_Label} is attached at ${_Target_Device} but is not mounted." 
    exit ${ExitCodeDestMount}
  else
    printf "%s" "${UpArrow}"
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

  if [[ "${optVerbose}" == "TRUE" ]]; then
    fn_msg_Info "Analyzing files..."
    _df_BEFORE=$(df -h ${_Source_Mount_Point} ${_Target_Mount_Point})
    _src_files_BEFORE=$(printf "%'d" $(find ${_Source_Mount_Point} | wc -l))
    _dst_files_BEFORE=$(printf "%'d" $(find ${_Target_Mount_Point} | wc -l))

    printf "%s" "$UpArrow";   fn_msg_Status ""

    fn_msg_Multiline "${_df_BEFORE}"
    fn_msg_Info "$(printf "Source contains:      %s files. (before)\n" "${_src_files_BEFORE}")"
    fn_msg_Info "$(printf "Destination contains: %s files. (before)\n" "${_dst_files_BEFORE}")"
  fi

  fn_msg_Info "Mirroring ${_Source_Mount_Point} to ${_Target_Mount_Point}"

  _Rsync_Flags=" --archive --partial --append --verbose "

  [[ "${optQuiet}" == "TRUE" ]] && _Rsync_Flags=${_Rsync_Flags/--verbose/} # ${OriginalString/Pattern/NewPattern}
  [[ "${optDryRun}" == "TRUE" ]] && _Rsync_Flags+=" --dry-run " 
  [[ "${optNoDelete}" != "TRUE" ]] && _Rsync_Flags+=" --delete-after " 
  [[ "${optVerbose}" == "TRUE" ]] && _Rsync_Flags+=" --itemize-changes --progress " 
  [[ "${optVerbose}" == "TRUE" ]] && fn_msg_Info "$(printf "Doing: rsync ${_Rsync_Flags} ${_Source_Mount_Point}/ ${_Target_Mount_Point}")"

  [[ -n "${_DEBUG}" ]] && exit $ExitCodeDebug

  rsync ${_Rsync_Flags} ${_Source_Mount_Point}/ ${_Target_Mount_Point}

  if [[ "${optVerbose}" == "TRUE" ]]; then
    _src_files_AFTER=$(printf "%'d" $(find ${_Source_Mount_Point} | wc -l))
    _dst_files_AFTER=$(printf "%'d" $(find ${_Target_Mount_Point} | wc -l))
    fn_msg_Info "DiskFree (before):"
    fn_msg_Multiline "${_df_BEFORE}"
    fn_msg_Status ""
    fn_msg_Info "DiskFree (after):"
    fn_msg_Multiline "$( df -h ${_Source_Mount_Point} ${_Target_Mount_Point} )"

    fn_msg_Status ""
    fn_msg_Info "$(printf "Source contained:      %s files. (before)\n" "${_src_files_BEFORE}")"
    fn_msg_Info "$(printf "Destination contained: %s files. (before)\n" "${_dst_files_BEFORE}")"
    fn_msg_Info "$(printf "Source now contains:      %s files. (after)\n" "${_src_files_AFTER}")"
    fn_msg_Info "$(printf "Destination now contains: %s files. (after)\n" "${_dst_files_AFTER}")"
  fi

} # End of function Main()

################################## Let's Roll ###############################################
#
# Let us begin...
START=$SECONDS

ParseParameters "$@" # Start by getting the Command Line Parameters

#  optDebug="TRUE"   # UnComment for forced debug (testing) mode

Initialize           # Set everything up based on command-line options specified 

Main                 # Get 'er done!

fn_msg_Success "That took $(date -d @$(( SECONDS - START )) +"%M:%S")."

exit ${ExitCodeOK}
