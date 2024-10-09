function IsSSHable() { # Simple function that evaluates logged-in-ability via SSH
# Input: SSH target (eg., '[user@]domain.name')
# Output: $?=0 if can be connected; non-zero otherwise
local _ssh_target=$1
  if [[ -z "${_ssh_target}" ]]; then # Caller didn't specify the ssh target node
    false
    return
  else
    echo ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${_ssh_target}" exit
    if [[ "$(ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${_ssh_target}" 'echo 0' )" == "0" ]] ; then
      true
      return
    else
      false
      return
    fi
  fi
} # End of function IsSSHable()

