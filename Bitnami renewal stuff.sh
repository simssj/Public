# Certbot-like bitnami renewal stuff:
# Ref: https://repost.aws/knowledge-center/lightsail-bitnami-renew-ssl-certificate

# Read 'current' cert:
sudo grep -irl "$(openssl s_client -verify_quiet -showcerts -connect paradisecleaningandhomecare.services:443 2>/dev/null | sed -n '/BEGIN/,/END/{p;/END/q}' | head -n 3 | tail -n 2)" /opt/bitnami/letsencrypt

# List 'available' certs:
sudo /opt/bitnami/letsencrypt/lego --path /opt/bitnami/letsencrypt list

# What was the email I used again?
sudo ls /opt/bitnami/letsencrypt/accounts/acm*


# Renew existing certs:
sudo /opt/bitnami/ctlscript.sh stop
sudo /opt/bitnami/letsencrypt/lego --tls --email="simssj@gmail.com" --domains="paradisecleaningandhomecare.services" --path="/opt/bitnami/letsencrypt" renew --days 90
sudo /opt/bitnami/ctlscript.sh start


