#!/usr/bin/env bash
# https://stackoverflow.com/questions/21297853/how-to-determine-ssl-cert-expiration-date-from-a-pem-encoded-certificate

CertFile="/tmp/cert.crt"

Domain="letsencrypt.org"
Domain="chesterfieldfencingandmore.com"

echo "" | openssl s_client -connect "${Domain}":443 -servername "${Domain}" -verify_hostname "${Domain}" 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > "${CertFile}" 

ExpirationDate=$(openssl x509 -enddate -noout -in  "${CertFile}" | awk -F= '{print $NF}' )
EffectiveDate=$(openssl x509 -startdate -noout -in  "${CertFile}" | awk -F= '{print $NF}' )

printf "Certificate Summary for %s:\n\tValid since: %s\n\tValid until: %s\n" "${Domain}" "${EffectiveDate}" "${ExpirationDate}" 

