
function root_check() {  # Check if current uid is root:
  if [ "$(id -u)" -eq "0" ]; then # Running as root
    return true
   else
    return false
  fi
}

function sudo_check() {  # Check if current uid can execute sudo commands:
  if [ "$(sudo id -u)" -eq "0" ]; then # Yes we can
    return true
  else
    return false
  fi
}


# Or.....
function RootCheck() {  # Check if current uid is root:
  [ "$(id -u)" -eq 0 ] &&  return 0 || return 1
}

function SudoCheck() {  # Check if current uid can execute sudo commands:
  [ "$(sudo id -u)" ] &&  return 0 || return 1
}

# Invoke as:
function main() {
  if RootCheck; then
    _cmd=""
  else
    if SudoCheck; then
      _cmd="sudo "
    else
      msg_Failure "No root privileges; cannot continue."
      exit 1
    fi
  fi

  :
}
