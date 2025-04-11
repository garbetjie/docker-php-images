#!/usr/bin/env bash

set -e

# Taken straight from /usr/local/bin/docker-entrypoint.sh
curl_put()
{
    RET=$(/usr/bin/curl -s -w '%{http_code}' -X PUT --data-binary @$1 --unix-socket /var/run/control.unit.sock http://localhost/$2)
    RET_BODY=$(echo $RET | /bin/sed '$ s/...$//')
    RET_STATUS=$(echo $RET | /usr/bin/tail -c 4)
    if [ "$RET_STATUS" -ne "200" ]; then
        echo "$0: Error: HTTP response status code is '$RET_STATUS'"
        echo "$RET_BODY"
        return 1
    else
        echo "$0: OK: HTTP response status code is '$RET_STATUS'"
        echo "$RET_BODY"
    fi
    return 0
}

cd /tmp

# Generate certificate.
openssl req \
  -x509 \
  -newkey rsa:4096 \
  -keyout key.pem \
  -out cert.pem \
  -days 365 \
  -nodes \
  -subj "/CN=localhost"

# Join them into a chain.
cat key.pem cert.pem > fullchain.pem

# Write the certificate.
curl_put fullchain.pem "certificates/localhost"

# Remove the cert files.
rm -f key.pem cert.pem fullchain.pem
