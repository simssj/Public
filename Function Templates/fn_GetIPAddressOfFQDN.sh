function GetIPAddressOfFQDN() { # Return one (of possibly many) IP address for a given FQDN
 # Input: Fully qualified domain name
 # Output: IP address (if found) or "UNKNOWN"
_TargetIP="UNKNOWN"
  if [[ -n "${1}" ]]; then
    _TargetIP=$(dig +noall +answer "${1}")
    if [[ -z ${_TargetIP} ]]; then
      _TargetIP="UNKNOWN"      
    fi
    # echo Target IP is \"${_TargetIP}\"
    if [[ ${_TargetIP} == *CNAME* ]]; then # More processing needed...
      _TargetCNAME=$(echo ${_TargetIP} | awk '{print $NF}')
      _TargetIP=$(dig +noall +answer "${_TargetCNAME}")
      if [[ ${_TargetIP} == *IN*A* ]]; then
        _TargetIP=$(echo "${_TargetIP}" | awk '{print $NF}' )
      else
        _TargetIP="UNKNOWN"
      fi
    else
      _TargetIP=$(echo ${_TargetIP} | awk '{print $NF}')
    fi
  fi
  echo "${_TargetIP}"
} # End of function GetIPAddressOfFQDN()
