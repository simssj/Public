#!/bin/bash
red=$(tput setaf 1)
green=`tput setaf 2`
reset=`tput sgr0`
clear
RES=0
DOWNCOUNT=0
if [ $# -eq 0 ]; then
 echo “Usage ./healthCheck.sh \<website_url\>”
 exit 1
else
 while true
 do
  RES=$(curl — max-time 5 -s $1 > /dev/null)
  RES=$?
  if [ $RES -eq 0 ]; then
   echo -en “${green}\rWebsite is UP! ${red}Down time=$DOWNCOUNT seconds${reset}”
  else
   echo -en “${red}\rWebsite is DOWN! Down time=$DOWNCOUNT  seconds${reset}”
   DOWNCOUNT=$(($DOWNCOUNT+1))
  fi
 sleep 10
 done
fi
