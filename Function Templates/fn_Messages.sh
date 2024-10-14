############################# fn_msg_ functions ##########################################
function fn_msg_Debug() { # Prints a provided 'debug' message. Try to keep it under ~70 characters
	[[ ${_INTERACTIVE} == True && -n "$Debug" ]] && printf "\r\e[2K   [\e[93m+\e[0m] "
	[[ -n "$Debug" ]] && printf "%s\n" "$@"
} # fn_msg_Info

function fn_msg_Info() { # Prints a provided 'info' message. Try to keep it under ~70 characters
	[[ ${_INTERACTIVE} == True ]] && printf "\r\e[2K   [\e[93mi\e[0m] "
	printf "%s\n" "$@"
} # fn_msg_Info

function fn_msg_Status() { # Prints a provided 'status' message. Try to keep it under ~70 characters
  [[ ${_INTERACTIVE} == True ]] && printf "\r\e[2K       "
	printf "%s\n" "$@"
} # fn_msg_Status

function fn_msg_Success() { # Prints a provided 'success' message. Try to keep it under ~70 characters
	[[ ${_INTERACTIVE} == True ]] && { sleep 1; printf "\r\e[2K   ✅ "; }
	printf "%s\n" "$@"
} # fn_msg_Success

function fn_msg_Failure() { # Prints a provided 'failure' message. Try to keep it under ~70 characters
  [[ ${_INTERACTIVE} == True ]] && printf "\r\e[2K   [\e[91m\xe2\x9d\x8c\e[0m] "
	printf "%s\n" "$@"
} # fn_msg_Failure
############################# End of fn_msg_ functions ######################################
