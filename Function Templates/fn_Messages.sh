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
  printf "\r$'\e'[A\r\e[2K   [\e[92m\xe2\x9c\x94\e[0m] %s\n" "$@"
} # fn_msg_Success
#


function fn_msg_Failure() { # Prints a generic failure message. Try to keep it under ~70 characters
  printf "\r\e[2K   [\e[91m\xe2\x9d\x8c\e[0m] %s\n" "$@"
} # fn_msg_Failure
#
############################# End of fn_msg_ functions ######################################
