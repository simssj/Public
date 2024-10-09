
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
