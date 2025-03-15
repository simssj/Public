#!/bin/bash

_scriptname=$(basename -s .sh "$0")

_logfile="/tmp/${_scriptname}.log"          # -->> Erase the logfile first?  cp /dev/null ${_logfile}
exec > >(tee -a "$_logfile") 2>&1

printf "%s is starting; validating environment...\n" $(basename "$0")

_source="/Volumes/Media/" 
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
  printf "\nStarting rsync of %s to %s.\n" "$_source" "$_destination" 
fi

# exit 0

_df_BEFORE=$(df -h "$_source" "$_destination")
printf "\n\nDiskFree (before):\n %s\n\n\n" "$_df_BEFORE"

_snapshot=$(which system_snapshot)
if [[ -n "$_snapshot" ]]; then
  printf "Running system_snapshot\n."  
  system_snapshot 
else
  printf "* * * Warning: system_snapshot not found on this system (Skipping).\n"
fi

rsync --archive --partial --append --itemize-changes "$_source" "$_destination" --delete --dry-run

printf "\n\nDiskFree (before):\n %s\n" "$_df_BEFORE"
printf "\n\nDiskFree (after):\n" 
df -h "$_source" "$_destination"

