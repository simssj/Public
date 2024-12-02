#!/bin/bash 

# To-Do:
# Sequence:
#   Stop container
#   Rename container
#   Pull new image!!!
#   Start container
#
# If interactive need to do an "are you sure?" confirmation if $@ is null
#
# Update "help" messaging
#
#

UpArrow=$'\e'[A # ; UpArrow="\000"

############################# fn_msg_ functions ##########################################
function fn_msg_Info() { # Prints a generic failure message. Try to keep it under ~70 characters
  printf "\r\e[2K   [\e[93mi\e[0m] %s\n" "$@"
} # fn_msg_Info
#

function fn_msg_Status() { # Prints a generic status message. Try to keep it under ~70 characters
  printf "\r\e[2K   [ ] %s\n" "$@"
} # fn_msg_Status
#

function fn_msg_Success() { # Moves the cursor up one line and then prints a generic success message. Try to keep it under ~70 characters
  printf "\r\e[2K   [\e[92m\xe2\x9c\x94\e[0m] %s\n" "$@"
} # fn_msg_Success
#

function fn_msg_Failure() { # Prints a generic failure message. Try to keep it under ~70 characters
  printf "\r\e[2K   [\e[91m\xe2\x9d\x8c\e[0m] %s\n" "$@"
} # fn_msg_Failure
#
############################# End of fn_msg_ functions ######################################

function YN() {  # Improved version as it is LOCALE specific
# Does nothing if response is affirmative; exits app if negative.
  set -- $(locale LC_MESSAGES)
  yesexpr="$1"; noexpr="$2"; yesword="$3"; noword="$4"

  while true; do
    read -p "Proceed (${yesword} / ${noword})? " yn
    if [[ "$yn" =~ $yesexpr ]]; then fn_msg_Success "Continuing..." ; break; fi
    if [[ "$yn" =~ $noexpr ]]; then fn_msg_Failure "Exiting per user request." ; exit 5; fi
    echo "Please respond with ${yesword} or ${noword}."
  done
} # End of function YN

function GetCommandLineParameters() {
  if [[ $# == 0 ]]; then # Specified no containers so do all containers
    if [[ "${-#*i}" == "$-" ]]; then
      ContainersToRefresh="${DefaultContainerList}"
      fn_msg_Info "You have not specific any targets. By default, all targets would be refreshed."
      printf "       That would include all of the following: %s\n" "${DefaultContainerList}"
#     printf "       %s\n" "Is this your intention?"

      while true; do
        read -p "       Is this your intention (${yesword} / ${noword})? " yn
        if [[ "$yn" =~ $yesexpr ]]; then fn_msg_Success "Continuing..." ; break; fi
        if [[ "$yn" =~ $noexpr ]]; then fn_msg_Failure "Exiting per user request." ; exit 5; fi
        echo "Please respond with ${yesword} or ${noword}."
      done

printf "Well, then, let's do it!"

#     YN
    fi
    ContainersToRefresh="${DefaultContainerList}"
  else # Need to validate proposed container (names) to refresh
    if [[ $# == 1 ]]; then 
      fn_msg_Info "$# refresh candidate was nominated"
    else
      fn_msg_Info "$# refresh candidates were nominated"
    fi

    ParameterIndex=0
    while [[ $# -gt 0 ]]; do
      ((++ParameterIndex))
      case $1 in
        homeassistant | portainer | prowlarr | radarr | readarr | sabnzbd | sonarr | test | alpine | lidarr | caddy | plex )
          ContainersToRefresh=" ${ContainersToRefresh} $1"
          fn_msg_Success "      $1"
          shift
          ;;
        --help)
            fn_msg_Status "This program will refresh the Docker containers nominated on the command line."
            fn_msg_Status "   If no containers are specified then all containers are refreshed. " 
          exit 0
          ;;
        *)
          fn_msg_Failure "Parameter ${ParameterIndex}, '$1', is not valid. Pass in --help for information on using this command."
          exit 1 
          ;;
      esac
    done
  fi
} # End of function GetCommandLineParameters

function DockerRefresh() {
  Index=$1

  if [[ -n ${Index} ]] ; then

    fn_msg_Status "Refreshing '${Index}'..."
    fn_msg_Status "Checking Docker info for '${Index}'..."
    GetContainerDetails "${Index}"

    if [[ "${ContainerName}" != "<NULL>" ]]; then
      printf "%s" "${UpArrow}"; fn_msg_Success "Docker container '${Index}' was found." 
      _NewContainerName="${ContainerName}-$(date '+%Y-%m-%d_%H.%M.%S')"
      fn_msg_Info "Stopping existing container: ${ContainerName}  (${ContainerID})..."
      Response=$( docker container stop "${ContainerID}" )
      if [[ ${Response} == "${ContainerID}" ]]; then
        printf "%s" "${UpArrow}"; fn_msg_Success "Container '${Index}' is stopped."
        fn_msg_Status "Renaming ${ContainerName} to ${_NewContainerName}"
        docker rename "${ContainerName}" "${_NewContainerName}" # Oddly, "Docker rename" doesn't print a result, but sets response code to '0' on success
        Response=$?
        if [[ ${Response} == 0 ]]; then
          printf "%s" "${UpArrow}"; fn_msg_Success "Docker container '${ContainerName}' was renamed to '${_NewContainerName}'" 
        fi
      fi      
    else
      fn_msg_Info "No Docker container '${Index}' was found." 
      _NewContainerName="<NULL>"
    fi

    PullDockerImage
    
    fn_msg_Status "Creating container: '${Index}'"
    _NewContainerID=$( docker create \
      --name="${Index}" \
      --net=host \
      --restart unless-stopped \
      -e PUID="${_UID}" \
      -e PGID="${_GID}" \
      -e TZ="${_TZ}" \
      -e UMASK=022 $_Extras \
      ${_Volumes} \
      ${_Image} )


    if [[ -n ${_NewContainerID} ]]; then
      printf "%s" "${UpArrow}"; fn_msg_Success "Created new container: '${Index}'"
      fn_msg_Status "Starting new container: ${Index}"
      Response=$( docker container start ${_NewContainerID} )
      if [[ "${Response}" == "${_NewContainerID}" ]]; then
        printf "%s" "${UpArrow}"; fn_msg_Success "Started new container: '${Index}'"
      else
        fn_msg_Failure "New container for ${Index} failed to start. Check logs."
      fi
    
    fi
  
  fi

} # End of function DockerRefresh

function GetContainerDetails() {  # 1st param must be the name of a container
  ContainerName="<NULL>" ; ContainerID="<NULL>" ; ContainerStatus="<NULL>"

  if [[ -n $1 ]] ; then
    ContainerStatus=$( docker container ls -a --filter name=$1 | grep \.$1$ )
    if [[ -n ${ContainerStatus} ]]; then  # A container was found named $1; Parse out the ContainerID:
      ContainerName=$1
      ContainerID=$( echo "${ContainerStatus}" | awk '{print $1}' )
    fi
  fi
} # End of function GetContainerDetails

function Main() {

  fn_msg_Status "Checking platform architecture..."
  _ARCH=$( uname )

  if [[ ${_ARCH} != "Linux" ]]; then
    fn_msg_Failure "Sorry, only Linux systems are supported at this time."
    exit 4
  else
    printf "%s" "${UpArrow}"; fn_msg_Success "Platform architecture checks out OK." 
  fi

  fn_msg_Status "Checking User..."
  if [[ "$( id -u )" != "0" ]]; then
    fn_msg_Failure "Sorry; this program requires that it be run by root."
    exit 3
  else
    printf "%s" "${UpArrow}"; fn_msg_Success "User (root) checks out OK." 
  fi

  fn_msg_Status "Checking for Plex info..."
  _UID=$( id -u plex )

  if [[ -z ${_UID} ]]; then
    fn_msg_Failure "UID for user 'plex' isn't found on this server. Continuing is not possible."
    exit 2
  else
    _GID=$( id -g plex )
    if [[ -z ${_GID} ]]; then
      fn_msg_Failure "GID for user 'plex' isn't found on this server. Continuing is not possible."
      exit 1
    else
      printf "%s" "${UpArrow}"; fn_msg_Success "Plex credentials check out OK:" 
    fi

  fi

  _TZ=$( cat /etc/timezone )
  if [[ -z ${_TZ} ]]; then
    _TZ="UTC"
  fi

    fn_msg_Info "  UID=${_UID}"
    fn_msg_Info "  GID=${_GID}"
    fn_msg_Info "  TZ=${_TZ}"

  fn_msg_Status "Starting Docker Container Refresh for: ${ContainersToRefresh}"

  for Index in ${ContainersToRefresh}; do

    unset _Volumes ; unset _Image ; unset _Extras

    case ${Index} in
      homeassistant | home-assistant)
        _Volumes="-v /Volumes/Media/AppData/homeassistant:/config"
        _Image="homeassistant/home-assistant:stable"
        ;;
      portainer)
        _Volumes="-v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data/portainer/portainer"
        _Image="portainer/portainer-ce:latest"
        ;;
      caddy)
        _Volumes="-v /Volumes/Media/AppData/caddy:/caddy"
        _Image="caddy:latest"
        _Extras=" --name=caddy -p 54321:8100 -e EnvTest=EnvTest "
        ;;
      plex)
        _Volumes="-v /Volumes/Media/AppData/Plex/${HOSTNAME}:/config -v /Volumes/Media/TV:/tv -v /Volumes/Media/Movies:/movies -v /Volumes/Media/Music:/music -v /Volumes/Media/Photos:/photo -v /tmp/transcode:/transcode"
        _Image="linuxserver/plex:latest"
        _Extras=" --name=plex -e VERSION=docker "
        ;;
      prowlarr)
        _Volumes="-v /Volumes/Media/AppData/prowlarr:/config"
        _Image="ghcr.io/hotio/prowlarr"
        ;;
      radarr)
        _Volumes="-v /Volumes/Media/AppData/radarr:/config -v /Volumes/Media/Downloads:/downloads -v /Volumes/Media/Movies:/movies"
        _Image="linuxserver/radarr:latest"
        ;;
      readarr)
        _Volumes="-v /Volumes/Media/AppData/readarr:/config -v /Volumes/Media/Downloads:/downloads -v /Volumes/Media/eBooks:/books"
        _Image="  linuxserver/readarr:nightly"
        ;;
      sabnzbd)
        _Volumes="-v /Volumes/Media/AppData/sabnzbd:/config  -v /Volumes/Media/Downloads:/downloads"
        _Image="linuxserver/sabnzbd:latest"
        ;;
      sonarr)
        _Volumes="-v /Volumes/Media/AppData/sonarr:/config -v /Volumes/Media/Downloads:/downloads -v /Volumes/Media/TV:/tv"
        _Image="linuxserver/sonarr:latest"
        ;;
      lidarr)
        _Volumes="-v /Volumes/Media/AppData/lidarr:/config -v /Volumes/Media/Downloads:/downloads -v /Volumes/Media/Shit_To_Save/lidarr:/music"
        _Image="lscr.io/linuxserver/lidarr:latest"
        ;;
      test | alpine)
        _Volumes="-v /Volumes/Media/AppData/test:/config"
        _Image="alpine:latest"
        ;;
      *)
        fn_msg_Info "* * * Error: Unknown Docker Container (\"%s\") specified; skipping"
        ;;
    esac

  if [[ -n ${_Volumes} && -n ${_Image} ]]; then
    DockerRefresh "${Index}"
  fi

  done

  fn_msg_Status "Refreshes completed."
} # End of function Main

function PullDockerImage() {
  fn_msg_Status "Refreshing image: '${_Image}' for container '${Index}'"
  _ImageName=$(echo ${_Image} | awk -F/ '{print $NF}')

  docker image pull ${_Image} 1>/tmp/PullDockerImageInfo_${_ImageName}.tmp 2>&1
  PullDockerImageResultCode=$?
  if [[ $PullDockerImageResultCode == 0 ]]; then
    fn_msg_Success "Successfully pulled image '${_Image}' for container '${Index}'."
    return
  else
    fn_msg_Failure "Something went horribly wrong pulling image '${_Image}' for container '${Index}'."
    cat /tmp/PullDockerImageInfo_${_ImageName}.tmp
    exit 6
  fi
} # End of function PullDockerImage

# Let the games begin:
# Set the valid Yes / No regex's and respons text(s)
  yesexpr="^[+1yY]"; noexpr="^[-0nN]"; yesword="yes"; noword="no"

fn_msg_Info "$0 is starting."

# set -e # Exit on error

DefaultContainerList="sabnzbd sonarr radarr readarr lidarr" # Note that portainer is not included by default for... reasons

GetCommandLineParameters "${@}"

if [[ -n $( echo ${ContainersToRefresh} | tr -d [:blank:] ) ]]; then
  Main
else
  fn_msg_Failure "No valid containers specified to be refreshed."
  exit 1
fi

exit 0
